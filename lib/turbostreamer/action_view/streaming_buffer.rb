# frozen_string_literal: true

class TurboStreamer
  module ActionView

    # Hands each chunk to a block as it is encoded rather than accumulating it,
    # so StreamingTemplateRenderer can push straight to the client instead of
    # buffering the whole response.
    #
    # Like Buffer, it subclasses its ActionView counterpart and takes over the
    # block that one was writing to, so the inherited methods stay consistent
    # with what has been written.
    class StreamingBuffer < ::ActionView::StreamingBuffer

      def initialize(block)
        @block = block
      end

      def write(value)
        string = value.to_s
        @block.call(string)
        string.bytesize
      end

    end

  end
end
