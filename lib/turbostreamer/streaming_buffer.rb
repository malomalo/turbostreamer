# frozen_string_literal: true

class TurboStreamer

  # Hands each chunk to a block as it is encoded rather than accumulating it,
  # so StreamingTemplateRenderer can push straight to the client instead of
  # buffering the whole response. This was ActionView::JSONStreamingBuffer.
  #
  # See TurboStreamer::Buffer for the non-streaming counterpart, which wraps an
  # ActionView buffer rather than a block.
  class StreamingBuffer

    def initialize(block)
      @block = block
    end

    def write(value)
      string = value.to_s
      @block.call(string)
      string.bytesize
    end
    alias_method :<<, :write
    alias_method :concat, :write
    alias_method :safe_concat, :write
    alias_method :append=, :write
    alias_method :safe_append=, :write

  end

end
