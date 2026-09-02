require 'test_helper'

# Exercises ActionView::StreamingTemplateRenderer, the path a controller takes
# for `render stream: true`.
class TurboStreamer::StreamingTest < ActiveSupport::TestCase

  # Streaming only engages when a layout is present, so the tests that aren't
  # about layouts use one that yields and nothing else.
  PASSTHROUGH_LAYOUT = 'json.yield!'

  def render_streaming(source, layout: 'layouts/app', layout_source: PASSTHROUGH_LAYOUT)
    resolver = ActionView::FixtureResolver.new(
      'test.json.streamer' => source,
      'layouts/app.json.streamer' => layout_source
    )
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([resolver]), formats: [:json], handlers: [:streamer]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    renderer = ActionView::StreamingTemplateRenderer.new(lookup_context)

    renderer.render(view, template: 'test', layout: layout)
  end

  # Consumes the body exactly once -- each pass re-runs the render, which would
  # double up the render_template.action_view notifications. Run with DEBUG=1
  # to see what came back.
  def chunks_from(body)
    [].tap do |chunks|
      body.each { |chunk| chunks << chunk }
    end
  end

  test "streams a template through StreamingTemplateRenderer" do
    body = render_streaming('json.object! { json.a 1; json.b "two" }')

    assert_kind_of ActionView::StreamingTemplateRenderer::Body, body
    assert_equal({ 'a' => 1, 'b' => 'two' }, JSON.parse(chunks_from(body).join))
  end

  # Body#each rescues Exception and substitutes an error page, so a raise inside
  # delayed_render_json never reaches the caller. Assert on the output instead.
  test "streaming does not fall back to the error page" do
    output = chunks_from(render_streaming('json.object! { json.a 1 }')).join

    refute_includes output, '500.html',
      'delayed_render_json raised; Body#each swallowed it into streaming_completion_on_exception'
    assert_equal({ 'a' => 1 }, JSON.parse(output))
  end

  test "streaming instruments render_template.action_view" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe('render_template.action_view') do |*args|
      events << args.last
    end

    begin
      chunks_from(render_streaming('json.object! { json.a 1 }'))
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_equal 1, events.size
    assert_match %r{test\.json\.streamer\z}, events.first[:identifier]
    assert_equal 'layouts/app', events.first[:layout]
  end

  test "a large document streams in more than one chunk" do
    # The Oj encoder flushes every BUFFER_SIZE bytes, so a document comfortably
    # over that arrives in pieces rather than all at once.
    source = 'json.array! { 2_000.times { |i| json.child! { json.object! { json.index i } } } }'
    chunks = chunks_from(render_streaming(source))

    assert_operator chunks.size, :>, 1,
      'expected the response to arrive in multiple chunks'
    assert_equal 2_000, JSON.parse(chunks.join).size
  end

  test "a layout wraps the template it yields to" do
    output = chunks_from(render_streaming(
      'json.object! { json.a 1; json.b "two" }',
      layout_source: 'json.object! { json.meta 1; json.key! :data; json.yield! }'
    )).join

    assert_equal({ 'meta' => 1, 'data' => { 'a' => 1, 'b' => 'two' } }, JSON.parse(output))
  end

  test "a layout can yield an array template" do
    output = chunks_from(render_streaming(
      'json.array! [1, 2, 3]',
      layout_source: 'json.object! { json.key! :data; json.yield! }'
    )).join

    assert_equal({ 'data' => [1, 2, 3] }, JSON.parse(output))
  end

  # The layout and the template share one builder, so the encoder tracks commas
  # and depth across the boundary rather than splicing two separate documents.
  test "a layout can yield in the middle of an array" do
    output = chunks_from(render_streaming(
      'json.object! { json.x 1 }',
      layout_source: 'json.array! { json.child! { json.object! { json.first 1 } }; json.child! { json.yield! } }'
    )).join

    assert_equal([{ 'first' => 1 }, { 'x' => 1 }], JSON.parse(output))
  end

  test "a large document still streams in chunks through a layout" do
    source = 'json.array! { 2_000.times { |i| json.child! { json.object! { json.index i } } } }'
    chunks = chunks_from(render_streaming(
      source, layout_source: 'json.object! { json.key! :data; json.yield! }'
    ))

    assert_operator chunks.size, :>, 1,
      'expected the layout-wrapped response to arrive in multiple chunks'
    assert_equal 2_000, JSON.parse(chunks.join)['data'].size
  end

  test "yield! outside a layout raises" do
    view = ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new([]), {}, nil)
    builder = TurboStreamer::Template.new(view)

    assert_raises(TurboStreamer::Errors::NothingToYieldError) { builder.yield! }
  end

  # A stream can't be replayed, and a yield! from inside the template would
  # otherwise recurse forever, so the content is single use.
  test "yielding twice does not render the template twice" do
    output = chunks_from(render_streaming(
      'json.object! { json.a 1 }',
      layout_source: 'json.array! { json.child! { json.yield! }; json.child! { json.yield! } }'
    )).join

    refute_includes output, '"a":1,{"a":1}', 'the template was rendered twice'
  end

end
