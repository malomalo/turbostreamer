# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require 'turbostreamer'
require 'turbostreamer/railtie'

require 'action_view'
require 'action_view/testing/resolvers'

require "active_support/testing/autorun"
require 'mocha/minitest'

if ENV["TSENCODER"]
  TurboStreamer.set_default_encoder(:json, ENV["TSENCODER"].to_sym)
end

# Registers the template handler and loads the ActionView extensions. The
# on_load :action_view hook this schedules fires when ActionView::Base is first
# used, so this is only the boot half of what a real app does.
TurboStreamer::Railtie.initializers.each(&:run)

# Tests under test/rails_integration exercise TurboStreamer through ActionView
# -- the template handler, the renderers, buffers and layouts -- rather than the
# builder on its own.
module RailsIntegration; end

class ActiveSupport::TestCase

  def jbuild(*args, &block)
    ::JSON.parse(TurboStreamer.encode(*args, &block))
  end

  def assert_json(json, &block)
    assert_equal json, jbuild(&block)
  end

  # Renders through ActionView::StreamingTemplateRenderer, the path a controller
  # takes for `render stream: true`. Returns the Rack body, which is a
  # StreamingTemplateRenderer::Body when streaming and a plain Array when not.
  def render_streaming(source, layout: 'layouts/app', layout_source: 'json.yield!')
    resolver = ActionView::FixtureResolver.new(
      'test.json.streamer' => source,
      'layouts/app.json.streamer' => layout_source
    )
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([resolver]), formats: [:json], handlers: [:streamer]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    renderer = ActionView::StreamingTemplateRenderer.new(lookup_context)

    body = renderer.render(view, template: 'test', layout: layout)
    [].tap { |chunks| body.each { |chunk| chunks << chunk } }
  end

  # Renders through the ordinary ActionView::TemplateRenderer -- what a
  # controller does without `stream: true`. Returns the rendered String.
  def render_template(source, layout: 'layouts/app', layout_source: 'json.yield!')
    resolver = ActionView::FixtureResolver.new(
      'test.json.streamer' => source,
      'layouts/app.json.streamer' => layout_source
    )
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([resolver]), formats: [:json], handlers: [:streamer]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    renderer = ActionView::TemplateRenderer.new(lookup_context)

    renderer.render(view, template: 'test', layout: layout).body
  end

  # Like render_template, but the fixture set is given explicitly -- for the
  # cases where the layout is in another format, or absent.
  def render_with_files(files, layout:)
    lookup_context = ActionView::LookupContext.new(
      ActionView::PathSet.new([ActionView::FixtureResolver.new(files)]),
      formats: [:json], handlers: [:streamer, :erb]
    )
    view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)

    ActionView::TemplateRenderer.new(lookup_context).render(view, template: 'test', layout: layout).body
  end

end
