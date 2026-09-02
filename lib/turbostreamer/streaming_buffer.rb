# frozen_string_literal: true

class TurboStreamer

  # Hands each chunk to a block as it is encoded rather than accumulating it,
  # so StreamingTemplateRenderer can push straight to the client instead of
  # buffering the whole response.
  #
  # See TurboStreamer::Buffer for the non-streaming counterpart, which wraps an
  # ActionView buffer rather than a block.
  class StreamingBuffer

    def initialize(block)
      @block = block
    end

    # The encoder is the only thing that writes here. Nothing renders ERB into
    # this buffer: delayed_render_json never applies the layout, and partial!
    # looks up `handlers: [:streamer]`, so a streamer template can only pull in
    # other streamer templates.
    def write(value)
      string = value.to_s
      @block.call(string)
      string.bytesize
    end

  end

end
