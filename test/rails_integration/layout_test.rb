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

  # json.yield! is the only way to place the template. A bare `yield` cannot
  # work: it returns a value, and the template is written into the stream at the
  # position the layout has reached rather than returned.
  test "a bare yield in a layout raises" do
    error = assert_raises(ActionView::Template::Error) do
      render_template('json.object! { json.a 1 }', layout_source: 'json.object! { json.data yield }')
    end

    assert_kind_of TurboStreamer::Errors::YieldError, error.cause
    assert_match 'json.yield!', error.cause.message
  end

  # Placing the template needs no hook in value!, which is why nothing overrides
  # it -- every template render would otherwise pay for a layouts-only feature.
  test "value! is not overridden on the builder" do
    assert_equal TurboStreamer, TurboStreamer::Template.instance_method(:value!).owner
  end

  test "json.yield! outside a layout raises" do
    view = ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new([]), {}, nil)
    builder = TurboStreamer::Template.new(view)

    assert_raises(TurboStreamer::Errors::NothingToYieldError) { builder.yield! }
  end

  test "a template without a layout is unaffected without streaming" do
    assert_equal({ 'a' => 1 }, JSON.parse(render_template('json.object! { json.a 1 }', layout: nil)))
  end

  # find_layout resolves a layout that exists in another format to nil rather
  # than raising -- an app with layouts/application.html.erb and no JSON layout.
  # Render without one, the way ActionView itself does.
  test "a layout that exists only in another format is skipped" do
    body = render_with_files(
      { 'test.json.streamer' => 'json.object! { json.a 1 }',
        'layouts/app.html.erb' => '[<%= yield %>]' },
      layout: 'layouts/app'
    )

    assert_equal({ 'a' => 1 }, JSON.parse(body))
  end

  test "skipping a layout for the wrong format is logged" do
    io = StringIO.new
    previous, ActionView::Base.logger = ActionView::Base.logger, Logger.new(io, level: Logger::DEBUG)

    begin
      render_with_files(
        { 'test.json.streamer' => 'json.object! { json.a 1 }',
          'layouts/app.html.erb' => '[<%= yield %>]' },
        layout: 'layouts/app'
      )
    ensure
      ActionView::Base.logger = previous
    end

    assert_match 'Skipped layout layouts/app', io.string
    assert_match ':json', io.string
  end

  test "a layout that exists in no format still raises" do
    assert_raises(ActionView::MissingTemplate) do
      render_with_files(
        { 'test.json.streamer' => 'json.object! { json.a 1 }' },
        layout: 'layouts/nope'
      )
    end
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

  # The layout's builder reaches the template through local_assigns, so both are
  # rendered as ActionView found them. Building a Template of our own to carry it
  # -- an earlier approach -- would compile on every render instead of once.
  test "the template is compiled once across renders" do
    compiles = 0
    counter = Module.new do
      define_method(:compile) { |mod| compiles += 1; super(mod) }
      private :compile
    end
    ActionView::Template.prepend(counter)

    resolver = ActionView::FixtureResolver.new(
      'test.json.streamer' => 'json.object! { json.a 1 }',
      'layouts/app.json.streamer' => 'json.object! { json.key! :data; json.yield! }'
    )
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([resolver]), formats: [:json], handlers: [:streamer]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)

    5.times do
      ActionView::TemplateRenderer.new(lookup_context).render(view, template: 'test', layout: 'layouts/app')
    end

    # The template and the layout, once each.
    assert_equal 2, compiles, 'the template is being recompiled on every render'
  end

  # As in ERB, where a layout without <%= yield %> renders without the template.
  test "a layout that never yields renders without the template" do
    output = render_template('json.object! { json.a 1 }', layout_source: 'json.object! { json.meta 1 }')

    assert_equal({ 'meta' => 1 }, JSON.parse(output))
  end

  # Also as in ERB -- except that ERB replays a buffered string, where each
  # yield here renders the template again.
  test "a layout can yield more than once" do
    output = render_template(
      'json.object! { json.a 1 }',
      layout_source: 'json.array! { json.child! { json.yield! }; json.child! { json.yield! } }'
    )

    assert_equal([{ 'a' => 1 }, { 'a' => 1 }], JSON.parse(output))
  end

  # The counter increments per render, so replaying a buffer would give the same
  # number twice.
  test "each yield renders the template again rather than replaying it" do
    $turbostreamer_yield_renders = 0
    output = render_template(
      'json.object! { json.n ($turbostreamer_yield_renders += 1) }',
      layout_source: 'json.object! { json.key! :first; json.yield!; json.key! :second; json.yield! }'
    )

    assert_equal({ 'first' => { 'n' => 1 }, 'second' => { 'n' => 2 } }, JSON.parse(output))
  end

  # A template has nothing to yield. It shares the layout's builder, so the
  # content is cleared while it renders -- otherwise it would still see it and
  # yield straight back into itself.
  test "json.yield! from inside the template raises" do
    error = assert_raises(ActionView::Template::Error) do
      render_template('json.object! { json.key! :oops; json.yield! }',
        layout_source: 'json.object! { json.key! :data; json.yield! }')
    end

    assert_kind_of TurboStreamer::Errors::NothingToYieldError, error.cause
  end

end
