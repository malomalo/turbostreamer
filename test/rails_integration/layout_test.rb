require 'test_helper'

# Layouts work the same whether or not the response is streamed. The tests
# below that use render_streaming go through StreamingTemplateRenderer; the
# "without streaming" ones go through the ordinary TemplateRenderer, which is
# what a controller uses by default. See streaming_test.rb for the renderer.
class RailsIntegration::LayoutTest < ActiveSupport::TestCase

  test "a layout wraps the template it yields to without streaming" do
    output = render_template(
      'json.object! { json.a 1; json.b "two" }',
      layout_source: 'json.object! { json.meta 1; json.key! :data; json.yield! }'
    )

    assert_equal({ 'meta' => 1, 'data' => { 'a' => 1, 'b' => 'two' } }, JSON.parse(output))
  end

  test "a layout can yield an array template without streaming" do
    output = render_template(
      'json.array! [1, 2, 3]',
      layout_source: 'json.object! { json.key! :data; json.yield! }'
    )

    assert_equal({ 'data' => [1, 2, 3] }, JSON.parse(output))
  end

  test "a layout can yield in the middle of an array without streaming" do
    output = render_template(
      'json.object! { json.x 1 }',
      layout_source: 'json.array! { json.child! { json.object! { json.f 1 } }; json.child! { json.yield! } }'
    )

    assert_equal([{ 'f' => 1 }, { 'x' => 1 }], JSON.parse(output))
  end

  test "a template without a layout is unaffected without streaming" do
    assert_equal({ 'a' => 1 }, JSON.parse(render_template('json.object! { json.a 1 }', layout: nil)))
  end

  test "a layout wraps the template it yields to" do
    output = render_streaming(
      'json.object! { json.a 1; json.b "two" }',
      layout_source: 'json.object! { json.meta 1; json.key! :data; json.yield! }'
    ).join

    assert_equal({ 'meta' => 1, 'data' => { 'a' => 1, 'b' => 'two' } }, JSON.parse(output))
  end

  test "a layout can yield an array template" do
    output = render_streaming(
      'json.array! [1, 2, 3]',
      layout_source: 'json.object! { json.key! :data; json.yield! }'
    ).join

    assert_equal({ 'data' => [1, 2, 3] }, JSON.parse(output))
  end

  # The layout and the template share one builder, so the encoder tracks commas
  # and depth across the boundary rather than splicing two separate documents.
  test "a layout can yield in the middle of an array" do
    output = render_streaming(
      'json.object! { json.x 1 }',
      layout_source: 'json.array! { json.child! { json.object! { json.first 1 } }; json.child! { json.yield! } }'
    ).join

    assert_equal([{ 'first' => 1 }, { 'x' => 1 }], JSON.parse(output))
  end

  test "a large document still streams in chunks through a layout" do
    source = 'json.array! { 2_000.times { |i| json.child! { json.object! { json.index i } } } }'
    chunks = render_streaming(
      source, layout_source: 'json.object! { json.key! :data; json.yield! }'
    )

    assert_operator chunks.size, :>, 1,
      'expected the layout-wrapped response to arrive in multiple chunks'
    assert_equal 2_000, JSON.parse(chunks.join)['data'].size
  end

  # The template is written into the stream, not returned, so it can't be placed
  # by the keyword. Without a block this failed as a bare "no block given".
  test "the yield keyword in a layout points at yield!" do
    error = assert_raises(ActionView::Template::Error) do
      render_template('json.object! { json.a 1 }', layout_source: 'json.object! { json.data yield }')
    end

    assert_kind_of TurboStreamer::Errors::YieldError, error.cause
    assert_match 'json.yield!', error.cause.message
  end

  test "yield! outside a layout raises" do
    view = ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new([]), {}, nil)
    builder = TurboStreamer::Template.new(view)

    assert_raises(TurboStreamer::Errors::NoTemplateToYieldError) { builder.yield! }
  end

  # A stream can't be replayed, and a yield! from inside the template would
  # otherwise recurse forever, so the content is single use.
  test "yielding twice does not render the template twice" do
    output = render_streaming(
      'json.object! { json.a 1 }',
      layout_source: 'json.array! { json.child! { json.yield! }; json.child! { json.yield! } }'
    ).join

    refute_includes output, '"a":1,{"a":1}', 'the template was rendered twice'
  end

end
