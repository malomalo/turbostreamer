# frozen_string_literal: true

class TurboStreamer

  # Writes to every target it holds: the encoder's real output, plus a buffer
  # for each capture in progress.
  #
  # This is what lets `capture` keep a copy of the bytes an encoder emits while
  # a block runs *without* moving the encoder somewhere else to emit them. The
  # encoder writes where it always would, in the position it is actually in, so
  # what gets captured is exactly what the document received -- no container to
  # stand a fragment up in, and nothing to strip back off afterwards.
  #
  # No #flush: nothing calls it. Oj and Wankel flush their own buffers by
  # writing into their output rather than by flushing it, and neither
  # ActionView buffer an encoder writes to responds to #flush either, so this
  # is as IO-like as what it stands in for.
  class Tee

    def initialize(io)
      @targets = [io]
    end

    # Byte count, as IO#write gives, rather than whatever the last target
    # happened to return.
    def write(string)
      @targets.each { |target| target.write(string) }
      string.bytesize
    end

    def push(buffer)
      @targets.push(buffer)
    end

    # Never removes the original target -- a capture only ever pops what it
    # pushed, and this makes losing the real output impossible rather than
    # merely unlikely.
    def pop
      @targets.pop if @targets.size > 1
    end

  end
end
