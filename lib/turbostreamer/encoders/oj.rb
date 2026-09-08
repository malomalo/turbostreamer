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
      # Whether a key has been written and is still owed its value. Oj's
      # writer knows but will not say, and inject has to know: in value
      # position a fragment can go through push_json, which places the colon.
      @awaiting_value = false
    end

    def key(k)
      if @pending_comma && @populated.last
        @stream_writer.flush
        @output.write(",")
        
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
          @output.write(",")
          
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
          @output.write(",")
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

      # A key is written and its value is what is being injected. push_json
      # places it, colon included, and counts it -- so no bookkeeping applies.
      if @awaiting_value
        @stream_writer.push_json(string)
        @awaiting_value = false
        return
      end

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
      # TODO: the pair-sequence path is the last thing bypassing the writer.
      #
      # A value under a key now goes through push_json (above). What is left is
      # `cache!` covering several pairs at once -- push_json needs a key in
      # object context, and a pair sequence is not a value, so these bytes still
      # go straight out and the delimiter stays ours to place. Requiring
      # `cache!` to wrap a single value would remove the last of it, and with it
      # @populated, @pending_comma, the comma branches in key/value/map_open/
      # array_open, the tails on both closes and every flush but the public one.
      #
      # Worth +15% on documents with no caching at all, since the cost is the
      # per-element bookkeeping rather than the injecting, and roughly nothing
      # on the pair-sequence shape itself. The price is group caching: one
      # fragment covering several keys that stay at the same level as live keys
      # would have no equivalent. jbuilder allows that form but caches a
      # Marshal'd Hash to do it; props_template forbids it for this reason.
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
      # A capture is a nested document: a map_open inside the block would
      # otherwise clear the outer key's pending value, and inject would not
      # know it can use push_json.
      old_awaiting = @awaiting_value
      @populated << false

      @output = (to || ::StringIO.new)
      @stream_writer = ::Oj::StreamWriter.new(@output, @options)

      # A value is captured whole, so it needs no enclosing container. The
      # dummy below exists only for a fragment of map pairs, which is not a
      # value and cannot stand alone.
      unless old_awaiting
        # This is to prevent error from OJ streamer
        # We will strip the brackets afterward
        if @stack.last == :map
          @stream_writer.push_object
        elsif @stack.last == :array
          @stream_writer.push_array
        end
      end

      yield

      @stream_writer.pop_all
      @stream_writer.flush
      result = output.string
      result.strip!
      result.delete_prefix!(',')
      result.delete_suffix!(",")

      # Strip brackets as promised above -- only if one was pushed
      if old_awaiting
        # nothing to strip: the capture is the value itself
      elsif @stack.last == :map
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
      @awaiting_value = old_awaiting
      @stream_writer = old_writer
      @output = old_output
    end

    def flush
      @stream_writer.flush
    end

  end
end
