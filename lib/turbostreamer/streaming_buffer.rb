# frozen_string_literal: true

# Hands each chunk to a block as it is encoded rather than accumulating it,
# so StreamingTemplateRenderer can push straight to the client instead of
# buffering the whole response.
class TurboStreamer::StreamingBuffer

  def initialize(block)
    @block = block
  end

  def write(value)
    string = value.to_s
    @block.call(string)
    string.bytesize
  end

end
