# frozen_string_literal: true

module ActionView

  # Hands each chunk to a block as it is encoded rather than accumulating it,
  # so StreamingTemplateRenderer can push straight to the client instead of
  # buffering the whole response.
  #
  # Like TurboBuffer, it subclasses its ActionView counterpart and takes over
  # the block that one was writing to, so the inherited methods stay consistent
  # with what has been written.
  class StreamingTurboBuffer < StreamingBuffer

    def initialize(block)
      @block = block
    end

    # The encoders -- and the C extensions behind them, Oj::StreamWriter and
    # Wankel::StreamEncoder -- write their output with the IO-style `write`,
    # which ActionView's buffers do not have.
    def write(value)
      string = value.to_s
      @block.call(string)
      string.bytesize
    end

  end

end
