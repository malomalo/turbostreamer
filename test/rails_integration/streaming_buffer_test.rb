require 'test_helper'

class RailsIntegration::StreamingBufferTest < ActiveSupport::TestCase

  test "#write hands each chunk to its block" do
    chunks = []
    buffer = TurboStreamer::StreamingBuffer.new(->(v) { chunks << v })
    builder = TurboStreamer.new(output_buffer: buffer)

    builder.object! { builder.key1 'value1' }
    builder.target!

    assert_equal '{"key1":"value1"}', chunks.join.strip
  end

  # This is the call StreamingTemplateRenderer#delayed_render_json makes.
  test "a template renders into a StreamingBuffer" do
    chunks = []
    buffer = TurboStreamer::StreamingBuffer.new(->(v) { chunks << v })
    source = 'json.object! { json.key1 "value1" }'
    template = ActionView::Template.new(source, 'test', TurboStreamer::Handler,
      format: :json, virtual_path: 'test', locals: [])

    template.render(ActionView::Base.with_empty_template_cache.new(
      ActionView::LookupContext.new([]), {}, nil), {}, buffer)

    assert_equal({ 'key1' => 'value1' }, JSON.parse(chunks.join))
  end

end
