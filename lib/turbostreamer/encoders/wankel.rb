# frozen_string_literal: true

require 'wankel'

class TurboStreamer
  class WankelEncoder < ::Wankel::StreamEncoder

    def initialize(io, options={})
      @stack = []
      @populated = []
      @awaiting_value = false
      @yajl_consumed_value = false
      @writing_value = false

      super(io, {mode: :as_json}.merge(options))
    end

    # Yajl does not check the shape of what it is given the way Oj's writer
    # does -- a key emitted into an array, or a key never given a value, came
    # out as malformed JSON rather than an error. Check here so both encoders
    # refuse the same things.
    def key(k)
      if @stack.last != :map
        raise ::TurboStreamer::Errors::StructureError.build('a key', @stack.last)
      end
      if @awaiting_value
        raise ::TurboStreamer::Errors::StructureError.build('a second key', :pending_key)
      end

      @awaiting_value = true
      string(k)
    end

    def value(v)
      if @stack.last == :map && !@awaiting_value && !@writing_value
        raise ::TurboStreamer::Errors::StructureError.build('a value without a key', @stack.last)
      end

      # @stack only ever holds :map or :array, so this is just depth > 0.
      @populated[-1] = true unless @stack.empty?
      @awaiting_value = false
      @writing_value = true

      super
    ensure
      @writing_value = false
    end

    def map_open
      @awaiting_value = false
      @stack << :map
      @populated << false
      super
    end

    def map_close
      if @awaiting_value
        raise ::TurboStreamer::Errors::StructureError.build('the end of an object', :pending_key)
      end
      @populated.pop

      @stack.pop
      super
      @populated[-1] = true if @stack.last
    end

    def array_open
      @awaiting_value = false
      @stack << :array
      @populated << false
      super
    end

    def array_close
      @populated.pop
      @stack.pop
      super
      @populated[-1] = true if @stack.last
    end

    def inject(string)
      flush

      # A key is written and its value is what is being injected: the colon is
      # ours, since these bytes never reach yajl.
      if @awaiting_value
        self.output.write(':'.freeze)
        # yajl only needs walking past the value if the capture below did not
        # already do it. On a cache hit no capture ran.
        capture { string("".freeze) } unless @yajl_consumed_value
        @yajl_consumed_value = false
        @awaiting_value = false
        return self.output.write(string)
      end

      # Otherwise these are pairs joining an open map, or elements joining an
      # open array. yajl neither delimits them nor counts them, and it only has
      # to be pushed past empty once per container: after that its count is
      # non-zero, so it delimits its own elements and the separator before an
      # injected one is ours. Walking it through an element -- one value for an
      # array, a key and a value for a map -- into a buffer that is thrown away
      # is what advances it.
      case @stack.last
      when :array
        if @populated.last
          self.output.write(',')
        else
          capture { string("") }
        end
        @populated[-1] = true
      when :map
        if @populated.last
          self.output.write(',')
        else
          capture { string(""); string("") }
        end
        @populated[-1] = true
      end

      self.output.write(string)
    end

    def capture(to=nil)
      flush
      old_output = self.output
      # @awaiting_value describes the document, but a capture is a nested one:
      # a map_open inside the block would otherwise clear the outer key's
      # pending value and inject would not know the colon is still owed.
      old_awaiting = @awaiting_value
      to = to || ::StringIO.new
      @populated << false
      self.output = to

      yield

      flush
      # Entered awaiting a value and the block supplied one, so yajl has
      # already advanced past it -- into `to`, which is discarded.
      @yajl_consumed_value = old_awaiting && !@awaiting_value
      # The leading colon is yajl's, emitted because the handle is shared. It
      # belongs to the position, not to the fragment, so a cached fragment must
      # not carry it.
      to.string.delete_prefix(':').delete_prefix(',').delete_suffix(",")
    ensure
      @populated.pop
      @awaiting_value = old_awaiting
      self.output = old_output
    end

  end
end
