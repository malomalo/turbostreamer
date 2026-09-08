# frozen_string_literal: true

require 'wankel'

class TurboStreamer
  class WankelEncoder < ::Wankel::StreamEncoder

    def initialize(io, options={})
      @stack = []
      @populated = []
      @awaiting_value = false

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
      # @stack only ever holds :map or :array, so this is just depth > 0.
      @populated[-1] = true unless @stack.empty?
      @awaiting_value = false

      super
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
      to = to || ::StringIO.new
      @populated << false
      self.output = to

      yield

      flush
      to.string.delete_prefix(',').delete_suffix(",")
    ensure
      @populated.pop
      self.output = old_output
    end

  end
end
