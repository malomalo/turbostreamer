require 'test_helper'

# Exercises ActionView::StreamingTemplateRenderer, the path a controller takes
# for `render stream: true`. See layout_test.rb for what a layout does with it.
class RailsIntegration::StreamingTest < ActiveSupport::TestCase

  test "streams a template through StreamingTemplateRenderer" do
    resolver = ActionView::FixtureResolver.new(
      'test.json.streamer' => 'json.object! { json.a 1; json.b "two" }',
      'layouts/app.json.streamer' => 'json.value! yield'
    )
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([resolver]), formats: [:json], handlers: [:streamer]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    renderer = ActionView::StreamingTemplateRenderer.new(lookup_context)
  
    body = renderer.render(view, template: 'test', layout: 'layouts/app')
    output = [].tap { |chunks| body.each { |chunk| chunks << chunk } }

    assert_kind_of ActionView::StreamingTemplateRenderer::Body, body
    assert_equal({ 'a' => 1, 'b' => 'two' }, JSON.parse(output.join()))
  end

  # Body#each rescues Exception and substitutes an error page, so a raise inside
  # delayed_render_json never reaches the caller. Assert on the output instead.
  test "streaming does not fall back to the error page" do
    output = render_streaming('json.object! { json.a 1 }').join

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
      render_streaming('json.object! { json.a 1 }')
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
    chunks = render_streaming(source)

    assert_operator chunks.size, :>, 1,
      'expected the response to arrive in multiple chunks'
    assert_equal 2_000, JSON.parse(chunks.join).size
  end

  # Streaming does not depend on there being a layout. Arriving in more than
  # one chunk is only possible if the response really was streamed.
  test "a template streams without a layout" do
    source = 'json.array! { 2_000.times { |i| json.child! { json.object! { json.index i } } } }'
    chunks = render_streaming(source, layout: nil)

    assert_operator chunks.size, :>, 1,
      'expected the response to arrive in multiple chunks with no layout'
    assert_equal 2_000, JSON.parse(chunks.join).size
  end

end
