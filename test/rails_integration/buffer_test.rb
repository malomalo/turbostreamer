require 'test_helper'

class RailsIntegration::BufferTest < ActiveSupport::TestCase

  test "::wrap passes through anything that already responds to #write" do
    io = StringIO.new
    assert_same io, TurboStreamer::Buffer.wrap(io)

    streaming = TurboStreamer::StreamingBuffer.new(->(v) {})
    assert_same streaming, TurboStreamer::Buffer.wrap(streaming)
  end

  test "::wrap adapts a buffer that has no #write" do
    buffer = TurboStreamer::Buffer.wrap(ActionView::OutputBuffer.new)

    assert_kind_of TurboStreamer::Buffer, buffer
    assert_kind_of ActionView::OutputBuffer, buffer.buffer
  end

  test "#write appends verbatim rather than HTML escaping" do
    buffer = TurboStreamer::Buffer.new(ActionView::OutputBuffer.new)
    buffer.write('{"a":"</script>"}')

    assert_equal '{"a":"</script>"}', buffer.to_s
  end

  test "#write returns the number of bytes written, as IO does" do
    buffer = TurboStreamer::Buffer.new(ActionView::OutputBuffer.new)

    assert_equal 4, buffer.write('narf')
    assert_equal 2, buffer.write('¡')
  end

  test "an encoder streams into a wrapped ActionView::OutputBuffer" do
    buffer = TurboStreamer::Buffer.wrap(ActionView::OutputBuffer.new)
    builder = TurboStreamer.new(output_buffer: buffer)

    builder.object! { builder.key1 'value1' }

    # target! hands back the ActionView buffer, not the wrapper, because
    # ActionView::Template#render only calls to_s on a result it recognizes.
    assert_kind_of ActionView::OutputBuffer, builder.target!
    assert_equal '{"key1":"value1"}', builder.target!.to_s.strip
  end

  test "an encoder streams into an ActionView::StreamingBuffer" do
    chunks = []
    buffer = TurboStreamer::Buffer.wrap(ActionView::StreamingBuffer.new(->(v) { chunks << v }))
    builder = TurboStreamer.new(output_buffer: buffer)

    builder.object! { builder.key1 'value1' }
    builder.target!

    assert_equal '{"key1":"value1"}', chunks.join.strip
  end

end
