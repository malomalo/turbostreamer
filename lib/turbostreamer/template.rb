# frozen_string_literal: true

require 'turbostreamer'

class TurboStreamer::Template < TurboStreamer

  def initialize(context, *args, &block)
    @context = context
    super(*args, &block)
  end

  # The proc that renders the template this layout wraps, for json.yield! to
  # place.
  attr_accessor :yield_content
  
  def partial!(name, locals: nil, **render_options)
    if name.class.respond_to?(:model_name) && name.respond_to?(:to_partial_path)
      return @context.render(name, json: self)
    end

    options = render_options
    options[:partial] = name
    options[:locals] = locals ? locals.dup : {} # TODO: move json to ivar so we don't have to dup
    options[:locals][:json] = self
    options[:handlers] = [:streamer]

    if options[:as]&.to_sym && options.key?(:collection)
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
      partial!(options[:partial], **options.except(:partial), collection: collection)
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
  # 
  # A miss renders straight into the document -- capture copies the bytes as
  # they go out rather than diverting them -- so only a hit has anything to
  # splice. Injecting on both paths would emit a miss twice.
  def cache!(key=nil, options={})
    return yield unless @context.controller.perform_caching

    key = _cache_key(key, options)
    if (cached = _read_fragment_cache(key, options))
      inject!(cached)
    else
      _write_fragment_cache(key, options) do
        _capture { _scope { yield self } }
      end
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
            _write_fragment_cache(key, options) do
              _capture { _scope { yield keys_to_collection_map[key] } }
            end
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

end