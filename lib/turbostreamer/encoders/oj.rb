# frozen_string_literal: true

require "oj"

class TurboStreamer
  class OjEncoder

    attr_reader :output

    BUFFER_SIZE = 4096

    def initialize(io, options={})
      @stack = []
      @populated = []

      @options = {mode: :json, buffer_size: BUFFER_SIZE}.merge(options)

      @output = io
      @stream_writer = ::Oj::StreamWriter.new(io, @options)
      @pending_comma = false
    end

    def key(k)
      if @pending_comma && @populated.last
        @stream_writer.flush
        @output.write(",")
        
      end
      @pending_comma = false
      @stream_writer.push_key(k)
    end

    def value(v)
      if !@stack.empty?
        @populated[-1] = true

        if @pending_comma && @populated.last
          @stream_writer.flush
          @output.write(",")
          
        end

      end
      
      @pending_comma = false
      @stream_writer.push_value(v)
    end

    def map_open
      if @pending_comma && @populated.last
        if @stack.last == :array
          @stream_writer.flush
          @output.write(",")
        end
        @pending_comma = false
      end
      
      @stack << :map
      @populated << false
      @stream_writer.push_object
    end

    def map_close
      @populated.pop
      @stack.pop
      @stream_writer.pop

      if @stack.last
        @populated[-1] = true
        @pending_comma = false
      end
    end

    def array_open
      @stack << :array
      @populated << false

      if @pending_comma
        @stream_writer.flush
        @output.write(",")
        @pending_comma = false
      end
      @stream_writer.push_array
    end

    def array_close
      @populated.pop
      @stack.pop
      @stream_writer.pop

      if @stack.last
         @populated[-1] = true
         @pending_comma = false
       end
    end

    def inject(string)
      string = string.delete_prefix(',').delete_suffix(",")

      # In an array Oj can place the fragment itself -- delimiter and element
      # count included -- so none of the bookkeeping below applies.
      if @stack.last == :array
        # A comma owed by an enclosing map still has to go out first, since Oj
        # knows nothing about it.
        if @pending_comma
          @stream_writer.flush
          @output.write(",")
          @pending_comma = false
        end

        @stream_writer.push_json(string)
        @populated[-1] = true
        return
      end

      # A map fragment is a bare sequence of pairs, and at the top level there
      # is no container at all. push_json can place neither, so those bytes go
      # to the output directly and the delimiter is ours to track.
      #
      # TODO: route this through push_json too, and delete the tracking.
      #
      # Blocked on `cache!` in an object caching a pair sequence
      # (`"a":1,"b":2`). push_json needs a key there -- unkeyed it raises "Can
      # not push onto an Object without a key", keyed it silently emits
      # `{"k":"a":1,"b":2}`. Requiring `cache!` to wrap a single value instead
      # (`json.person { json.cache!(k) { json.object! { ... } } }`) makes
      # push_key + push_json work, and then nothing bypasses the writer:
      # @populated, @pending_comma, the comma branches in key/value/map_open/
      # array_open, the tails on both closes and every flush but the public one
      # all go -- 43 lines, and the source of every delimiter bug here.
      #
      # Worth +15% on documents with no caching at all, since the cost is the
      # per-element bookkeeping rather than the injecting. Measured -3% on the
      # map-fragment shape itself, so this is a simplification rather than a
      # speed-up where it applies.
      #
      # The price is group caching: one fragment covering several keys that stay
      # at the same level as live keys has no equivalent afterwards. jbuilder
      # allows that form but caches a Marshal'd Hash to do it; props_template
      # forbids it for this exact reason. Breaking change either way -- it
      # inverts the caveat documented in the README.
      @stream_writer.flush

      if @stack.last && @populated.last
        @output.write(",")
      elsif @stack.last
        @pending_comma = true
        @populated[-1] = true
      end

      self.output.write(string)
    end

    def capture(to=nil)
      @stream_writer.flush

      old_writer = @stream_writer
      old_output = @output
      @populated << false

      @output = (to || ::StringIO.new)
      @stream_writer = ::Oj::StreamWriter.new(@output, @options)

      # This is to prevent error from OJ streamer
      # We will strip the brackets afterward
      if @stack.last == :map
        @stream_writer.push_object
      elsif @stack.last == :array
        @stream_writer.push_array
      end

      yield

      @stream_writer.pop_all
      @stream_writer.flush
      result = output.string
      result.strip!
      result.delete_prefix!(',')
      result.delete_suffix!(",")

      # Strip brackets as promised above
      if @stack.last == :map
        result.delete_prefix!('{')
        result.delete_suffix!("}")
      elsif @stack.last == :array
        result.delete_prefix!('[')
        result.delete_suffix!("]")
      end

      # Possible for `output.string` to have value like
      # `[,{"key":"value"}]\n`
      # Thus the comma must be removed here
      result.delete_prefix!(',')
      result
    ensure
      @populated.pop
      @stream_writer = old_writer
      @output = old_output
    end

    def flush
      @stream_writer.flush
    end

  end
end
