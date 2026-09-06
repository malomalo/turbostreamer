# frozen_string_literal: true

require 'turbostreamer'

class TurboStreamer::Template < TurboStreamer
  
  class << self
    attr_accessor :template_lookup_options
  end

  self.template_lookup_options = { handlers: [:streamer] }

  def initialize(context, *args, &block)
    @context = context
    super(*args, &block)
  end

  # The proc that renders the template this layout wraps, for json.yield! to
  # place.
  attr_accessor :yield_content
  
  # `:as` and `:collection` are options rather than template locals, so they are
  # named as such. Everything else is a local and lands in the keyword rest,
  # which Ruby builds fresh on every call -- so the caller's own hash is never
  # written to, where the previous signature took it positionally and deleted
  # `:as` out of it.
  #
  # `collection:` defaults to BLANK rather than nil, because a nil collection is
  # meaningful: `partial! 'post', collection: nil, as: :post` renders `[]`.
  def partial!(name = nil, as: nil, collection: BLANK, **locals)
    if name.class.respond_to?(:model_name) && name.respond_to?(:to_partial_path)
      return @context.render(name, json: self)
    end

    if ::Hash === name
      raise ::ArgumentError, 'pass partial options as keywords: ' \
        "`json.partial! **options` rather than `json.partial! options`"
    end

    if name.nil?
      # partial! partial: 'name', collection: @posts, as: :post
      # The keywords were split across the parameters above; put them back. The
      # rest is fresh, but a :locals passed within it is the caller's.
      options = locals
      options[:locals] = options[:locals].dup if options[:locals]
      options[:as] = as if as
      options[:collection] = collection unless _blank?(collection)
    elsif locals.one? && locals.key?(:locals)
      # partial! 'name', locals: { ... } -- the rest is fresh but the hash
      # under :locals is the caller's.
      options = locals.merge(partial: name)
      options[:locals] = options[:locals].dup if options[:locals]
      options[:as] = as if as.present?
      options[:collection] = collection unless _blank?(collection)
    else
      # partial! 'name', foo: 'bar'
      options = { partial: name, locals: locals }
      options[:as] = as if as.present?
      unless _blank?(collection)
        options[:collection] = collection
        # :collection is left in the locals as well, so a partial can refer to
        # the whole collection under that name and not just its own element.
        locals[:collection] = collection
      end
    end

    # Everything below is written to, and the branches above guarantee the
    # options are ours: the keyword forms build them, the two options-hash
    # forms copy the caller's.
    options.reverse_merge! ::TurboStreamer::Template.template_lookup_options
    (options[:locals] ||= {})[:json] = self

    # :as reads from the options rather than the keyword, because the
    # options-hash forms carry it there and never bind the keyword.
    if options[:as]&.to_sym && options.key?(:collection)
      # One render for the whole collection, so Action View's find_template --
      # one of its heavier calls -- runs once instead of per element.
      array! { @context.render(options) }
    else
      @context.render(options)
    end
  end

  # The same thing as a statement rather than a value, for a layout that would
  # rather write the key itself:
  #
  #   json.key! :data
  #   json.yield!
  def yield!
    content = @yield_content
    # The same thing Ruby says for a `yield` with no block behind it, because
    # that is what this is.
    raise ::LocalJumpError, 'no block given (yield)' if content.nil?

    # The template renders through this same builder, so it would otherwise
    # still see the content and yield straight back into itself. Clear it while
    # it renders -- a template has nothing to yield -- and put it back, so a
    # layout can go on to yield again.
    begin
      @yield_content = nil
      content.call(self)
    ensure
      @yield_content = content
    end
  end

  def array!(collection = BLANK, *attributes, &block)
    options = attributes.extract_options!

    if options.key?(:partial)
      partial!(**options, collection: collection)
    else
      super
    end
  end

  # Caches the json constructed within the block passed. Has the same signature
  # as the `cache` helper method in `ActionView::Helpers::CacheHelper` and so
  # can be used in the same way.
  #
  # Example:
  #
  #   json.cache! ['v1', @person], expires_in: 10.minutes do
  #     json.extract! @person, :name, :age
  #   end
  def cache!(key=nil, options={})
    if @context.controller.perform_caching
      value = _cache_fragment_for(key, options) do
        _capture { _scope { yield self }; }
      end

      inject!(value)
    else
      yield
    end
  end
  
  # Caches a collection of objects using fetch_multi, if supported.
  # Requires a block for each item in the array. Accepts optional 'key' attribute
  # in options (e.g. key: 'v1').
  #
  # Example:
  #
  # json.cache_collection! @people, expires_in: 10.minutes do |person|
  #   json.partial! 'person', :person => person
  # end
  def cache_collection!(collection, options = {}, &block)
    if @context.controller.perform_caching
      keys_to_collection_map = _keys_to_collection_map(collection, options)
      results = _read_multi_fragment_cache(keys_to_collection_map.keys, options)
      
      array! do
        keys_to_collection_map.each_key do |key|
          if results[key]
            inject!(results[key])
          else
            value = _write_fragment_cache(key, options) do
              _capture { _scope { yield keys_to_collection_map[key] } }
            end
            inject!(value)
          end
        end
      end
    else
      array! collection, options, &block
    end
  end

  # Conditionally catches the json depending in the condition given as first
  # parameter. Has the same signature as the `cache` helper method in
  # `ActionView::Helpers::CacheHelper` and so can be used in the same way.
  #
  # Example:
  #
  #   json.cache_if! !admin?, @person, expires_in: 10.minutes do
  #     json.extract! @person, :name, :age
  #   end
  def cache_if!(condition, *args, &block)
    condition ? cache!(*args, &block) : yield
  end

  private

  def _keys_to_collection_map(collection, options)
    key = options.delete(:key)
    
    collection.inject({}) do |result, item|
      key = key.respond_to?(:call) ? key.call(item) : key
      cache_key = key ? [key, item] : item
      result[_cache_key(cache_key, options)] = item
      result
    end
  end

  def _cache_fragment_for(key, options, &block)
    key = _cache_key(key, options)
    _read_fragment_cache(key, options) || _write_fragment_cache(key, options, &block)
  end

  def _read_multi_fragment_cache(keys, options = nil)
    @context.controller.instrument_fragment_cache :read_multi_fragment, keys do
      ::Rails.cache.read_multi(*keys, options)
    end
  end

  def _read_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :read_fragment, key do
      ::Rails.cache.read(key, options)
    end
  end

  def _write_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :write_fragment, key do
      yield.tap do |value|
        ::Rails.cache.write(key, value, options)
      end
    end
  end

  def _cache_key(key, options)
    name_options = options.slice(:skip_digest, :virtual_path)
    key = _fragment_name_with_digest(key, name_options)

    if @context.respond_to?(:combined_fragment_cache_key)
      key = @context.combined_fragment_cache_key(key)
    elsif ::Hash === key
      key = url_for(key).split('://', 2).last
    end

    ::ActiveSupport::Cache.expand_cache_key(key, :streamer)
  end

  def _fragment_name_with_digest(key, options)
    if @context.respond_to?(:cache_fragment_name)
      # Current compatibility, fragment_name_with_digest is private again and cache_fragment_name
      # should be used instead.
      @context.cache_fragment_name(key, **options)
    elsif @context.respond_to?(:fragment_name_with_digest)
      # Backwards compatibility for period of time when fragment_name_with_digest was made public.
      @context.fragment_name_with_digest(key)
    else
      key
    end
  end

  # The base rule, plus the case only Rails has: a nil collection rendered
  # through a partial -- `json.comments nil, partial: 'comment/comment', as:
  # :comment` -- has to reach array! to come out as [] rather than being
  # treated as a single object to extract from.
  #
  # Written out rather than calling super, because child! runs this on every
  # element and the second dispatch showed up. It stays here rather than moving
  # into TurboStreamer because partial! is a Template method: in a plain
  # builder the `:as` clause has nothing to route to, and would only turn
  # `json.foo nil, as: :x` from a TypeError into [].
  def _eachable_arguments?(value, *args)
    return true if value.respond_to?(:each) && !value.is_a?(Hash)

    options = args.last
    ::Hash === options && options.key?(:as)
  end

end