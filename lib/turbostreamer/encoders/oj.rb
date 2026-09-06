# frozen_string_literal: true

require "oj"

class TurboStreamer
  class OjEncoder

    attr_reader :output

    BUFFER_SIZE = 4096

    def initialize(io, options={})
      @stack = []
      @indexes = []
      @oj_counts = []

      @options = {mode: :json, buffer_size: BUFFER_SIZE}.merge(options)

      @output = io
      @stream_writer = ::Oj::StreamWriter.new(io, @options)
    end

    # Two counts per open container:
    #
    #   @indexes    every element present, including injected ones
    #   @oj_counts  only the elements the writer emitted itself
    #
    # They diverge because inject writes bytes straight to the output, behind
    # the writer's back. The writer emits a delimiter before every element
    # after its own first, so the separator is ours to write exactly when the
    # container already holds something but the writer's own count is zero.
    def separate!
      if @indexes.last.to_i > 0 && @oj_counts.last.to_i.zero?
        @stream_writer.flush
        @output.write(",".freeze)
      end
    end

    # A map counts key/value pairs, so the key opens an element; an array
    # counts values, so the value or container does. At the top level there is
    # no enclosing container to count against.
    def start_element!
      return unless @stack.last == :array

      separate!
      @indexes[-1] += 1
      @oj_counts[-1] += 1
    end

    def key(k)
      separate!
      @indexes[-1] += 1
      @oj_counts[-1] += 1
      @stream_writer.push_key(k)
    end

    def value(v)
      start_element!
      @stream_writer.push_value(v)
    end

    def map_open
      start_element!
      @stack << :map
      @indexes << 0
      @oj_counts << 0
      @stream_writer.push_object
    end

    def map_close
      @indexes.pop
      @oj_counts.pop
      @stack.pop
      @stream_writer.pop
    end

    def array_open
      start_element!
      @stack << :array
      @indexes << 0
      @oj_counts << 0
      @stream_writer.push_array
    end

    def array_close
      @indexes.pop
      @oj_counts.pop
      @stack.pop
      @stream_writer.pop
    end

    def inject(string)
      @stream_writer.flush

      if @stack.empty? || string.empty?
        return @output.write(string)
      end

      # Separate from what precedes this, whichever side of the count is
      # behind: separate! covers the injected-then-injected case, and the
      # writer's own count covers an element it wrote itself.
      separate!
      @output.write(",".freeze) if @indexes.last > 0 && !@oj_counts.last.zero?

      # Counted as present, but deliberately not against the writer -- it did
      # not emit these bytes and so will not delimit after them.
      @indexes[-1] += 1

      @output.write(string.sub(/\A,/, ''.freeze).chomp(",".freeze).strip)
    end

    def capture(to=nil)
      @stream_writer.flush

      old_writer = @stream_writer
      old_output = @output
      @indexes << 0
      @oj_counts << 0

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
      result = output.string.sub(/\A,/, ''.freeze).chomp(",".freeze).strip

      # Strip brackets as promised above
      if @stack.last == :map
        result = result.sub(/\A{/, ''.freeze).chomp("}".freeze)
      elsif @stack.last == :array
        result = result.sub(/\A\[/, ''.freeze).chomp("]".freeze)
      end

      # Possible for `output.string` to have value like
      # `[,{"key":"value"}]\n`
      # Thus the comma must be removed here
      result.sub(/\A,/, ''.freeze)
    ensure
      @indexes.pop
      @oj_counts.pop
      @stream_writer = old_writer
      @output = old_output
    end

    def flush
      @stream_writer.flush
    end

  end
end
