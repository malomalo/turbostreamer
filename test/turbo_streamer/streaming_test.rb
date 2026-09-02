require 'test_helper'

# Exercises ActionView::StreamingTemplateRenderer, the path a controller takes
# for `render stream: true`. Nothing else in the suite reaches it, which is how
# it stayed broken from Rails 6.1 onward without a test noticing.
class TurboStreamer::StreamingTest < ActiveSupport::TestCase

  LAYOUT = 'json.object! { json.layout true }'

  def render_streaming(source, layout: 'layouts/app')
    resolver = ActionView::FixtureResolver.new(
      'test.json.streamer' => source,
      'layouts/app.json.streamer' => LAYOUT
    )
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([resolver]), formats: [:json], handlers: [:streamer]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    renderer = ActionView::StreamingTemplateRenderer.new(lookup_context)

    renderer.render(view, template: 'test', layout: layout)
  end

  def chunks_from(body)
    [].tap { |chunks| body.each { |chunk| chunks << chunk } }
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

end
