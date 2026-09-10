# frozen_string_literal: true

class TurboStreamer

  # Passes everything through to the real output, and additionally to any
  # buffers pushed onto it.
  #
  # This is what lets `capture` keep a copy of the bytes an encoder emits while
  # a block runs *without* moving the encoder somewhere else to emit them. The
  # encoder writes where it always would, in the position it is actually in, so
  # what gets captured is exactly what the document received -- no container to
  # stand a fragment up in, and nothing to strip back off afterwards.
  class Tee

    def initialize(io)
      @io = io
      @copies = []
    end

    def write(string)
      @copies.each { |copy| copy.write(string) }
      @io.write(string)
    end

    def flush
      @io.flush if @io.respond_to?(:flush)
    end

    def push(buffer)
      @copies.push(buffer)
    end

    def pop
      @copies.pop
    end

  end
end
