# frozen_string_literal: true

require 'wankel'

class TurboStreamer
  class WankelEncoder < ::Wankel::StreamEncoder

    def initialize(io, options={})
      @stack = []
      @indexes = []

      super(io, {mode: :as_json}.merge(options))
    end

    def key(k)
      string(k)
    end

    def value(v)
      # @stack only ever holds :map or :array, so this is just depth > 0.
      @indexes[-1] += 1 unless @stack.empty?
      super
    end

    # A container is an element of whatever encloses it -- one slot of an
    # array, or the value half of a map pair -- so it counts against the
    # parent exactly like a scalar does. Without this only scalars were
    # counted, and inject read an array whose elements were all objects as
    # still empty and skipped the separator before itself.
    def count_in_parent!
      @indexes[-1] += 1 unless @stack.empty?
    end

    def map_open
      count_in_parent!
      @stack << :map
      @indexes << 0
      super
    end

    def map_close
      @indexes.pop
      @stack.pop
      super
    end

    def array_open
      count_in_parent!
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

      # Yajl emits its own delimiters, but these bytes go straight to the
      # output behind its back, so it neither writes the separator before them
      # nor counts them. Write the separator here, then walk Yajl through an
      # element's worth of state -- into a throwaway buffer -- so it delimits
      # whatever comes next. An array element is one value; a map element is a
      # key and a value.
      if @stack.last == :array
        self.output.write(','.freeze) if @indexes.last > 0
        capture do
          string("".freeze)
        end
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
