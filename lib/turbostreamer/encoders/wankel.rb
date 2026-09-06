# frozen_string_literal: true

require 'wankel'

class TurboStreamer
  class WankelEncoder < ::Wankel::StreamEncoder

    def initialize(io, options={})
      @stack = []
      @indexes = []
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
      @indexes[-1] += 1 unless @stack.empty?
      @awaiting_value = false
      super
    end

    def map_open
      @awaiting_value = false
      @stack << :map
      @indexes << 0
      super
    end

    def map_close
      if @awaiting_value
        raise ::TurboStreamer::Errors::StructureError.build('the end of an object', :pending_key)
      end
      @indexes.pop
      @stack.pop
      super
    end

    def array_open
      @awaiting_value = false
      @stack << :array
      @indexes << 0
      super
    end

    def array_close
      @indexes.pop
      @stack.pop
      super
    end

    def inject(string)
      flush

      if @stack.last == :array
        self.output.write(','.freeze) if @indexes.last > 0
        @indexes[-1] += 1
      elsif @stack.last == :map
        self.output.write(','.freeze) if @indexes.last > 0
        capture do
          string("".freeze)
          string("".freeze)
        end
        @indexes[-1] += 1
      end

      self.output.write(string)
    end

    def capture(to=nil)
      flush
      old_output = self.output
      to = to || ::StringIO.new
      @indexes << 0
      self.output = to

      yield

      flush
      to.string.sub(/\A,/, ''.freeze).chomp(",".freeze)
    ensure
      @indexes.pop
      self.output = old_output
    end

  end
end
