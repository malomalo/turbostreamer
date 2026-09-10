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

      # An Oj writer cannot be retargeted after construction, so it is handed
      # a Tee from the start and capture switches copying on. @output stays the
      # real io, which is what target! hands back.
      @output = io
      @tee = Tee.new(io)
      @stream_writer = ::Oj::StreamWriter.new(@tee, @options)
      @pending_comma = false
      # Whether a key has been written and is still owed its value. Oj's writer
      # knows but will not say, and inject has to know: in value position a
      # fragment goes through push_json, which places the colon, and everywhere
      # else in a map it cannot.
      @awaiting_value = false
    end

    def key(k)
      if @pending_comma && @populated.last
        @stream_writer.flush
        @tee.write(",")
        
      end
      @pending_comma = false
      @awaiting_value = true
      @stream_writer.push_key(k)
    end

    def value(v)
      if !@stack.empty?
        @populated[-1] = true

        if @pending_comma && @populated.last
          @stream_writer.flush
          @tee.write(",")
          
        end

      end
      
      @pending_comma = false
      @awaiting_value = false
      @stream_writer.push_value(v)
    end

    def map_open
      if @pending_comma && @populated.last
        if @stack.last == :array
          @stream_writer.flush
          @tee.write(",")
        end
        @pending_comma = false
      end
      
      @awaiting_value = false
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
      @awaiting_value = false
      @stack << :array
      @populated << false

      if @pending_comma
        @stream_writer.flush
        @tee.write(",")
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

      # A comma owed by an enclosing map has to go out first: Oj knows nothing
      # about it, so it would otherwise land after the fragment.
      if @pending_comma && @stack.last == :array
        @stream_writer.flush
        @tee.write(",")
        @pending_comma = false
      end

      # Oj places the fragment itself -- the colon after a key, or an array
      # delimiter, and the element count with it -- everywhere except a bare
      # sequence of pairs joining an open map, which is neither a value nor
      # something with a key of its own.
      #
      # Oj will say which by raising, and survives being asked, but asking
      # costs an exception on every cache hit that replays a pair sequence --
      # the shape `json.cache!` produces when it wraps a key, which is the
      # common one. Tracking the position instead is two ivar writes on the
      # hot path and none here.
      if @awaiting_value || @stack.last != :map
        @stream_writer.push_json(string)
        @populated[-1] = true if @stack.last == :array
        @awaiting_value = false
        return
      end

      @stream_writer.flush

      if @stack.last && @populated.last
        @tee.write(",")
      elsif @stack.last
        @pending_comma = true
        @populated[-1] = true
      end

      @tee.write(string)
    end

    def capture(to=nil)
      # Bytes owed from before the capture belong to the document rather than
      # to the fragment -- a pending key's `"author":` among them.
      @stream_writer.flush

      buffer = to || ::StringIO.new
      @tee.push(buffer)

      begin
        yield
        # Oj buffers, so the fragment is only whole once it has been pushed out.
        @stream_writer.flush
      ensure
        @tee.pop
      end

      result = buffer.string
      result.strip!
      # The delimiter Oj wrote belongs to the position this was rendered in,
      # not to the fragment, so a replay somewhere else must not carry it.
      result.delete_prefix!(',')
      result.delete_suffix!(",")
      result
    end

    def flush
      @stream_writer.flush
    end

  end
end
