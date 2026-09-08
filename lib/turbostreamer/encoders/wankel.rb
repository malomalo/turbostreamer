# frozen_string_literal: true

require 'wankel'

class TurboStreamer
  class WankelEncoder < ::Wankel::StreamEncoder

    def initialize(io, options={})
      @stack = []
      @populated = []

      super(io, {mode: :as_json}.merge(options))
    end

    def key(k)
      string(k)
    end

    def value(v)
      # @stack only ever holds :map or :array, so this is just depth > 0.
      @populated[-1] = true unless @stack.empty?
      super
    end

    def map_open
      @stack << :map
      @populated << false
      super
    end

    def map_close
      @populated.pop
      @stack.pop
      super
      @populated[-1] = true if @stack.last
    end

    def array_open
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
