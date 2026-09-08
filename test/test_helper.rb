# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'json'
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

# Registers the template handler and schedules an on_load :action_view hook
# that loads the ActionView extensions.
TurboStreamer::Railtie.initializers.each(&:run)

# That hook does not fire until ActionView::Base is first used, and the
# extensions -- ActionView::TurboBuffer and friends -- do not exist
# until it does. Booting a real app loads ActionView::Base long before anything
# renders; force it here so tests see the same thing whatever order they run in.
ActionView::Base.with_empty_template_cache

# Tests under test/rails_integration exercise TurboStreamer through ActionView
# -- the template handler, the renderers, buffers and layouts -- rather than the
# builder on its own.
module RailsIntegration; end

# ActionView's LogSubscriber resolves paths against Rails.root, so any test that
# sets a logger needs it.
module Rails
  def self.root
    @root ||= File.expand_path('../..', __FILE__)
  end
end

class ActiveSupport::TestCase

  # Several tests reach into TurboStreamer's class-level configuration:
  # options_test replaces the encoder defaults wholesale, the timestamp test
  # re-runs the railtie to simulate boot, and the key formatter tests set the
  # global formatter. None of it was restored, so what ran earlier decided what
  # later tests were configured with.
  #
  # That made `rake test:wankel` untrustworthy rather than merely untidy.
  # Setting the default encoder to :oj loads Oj as a side effect, and blanking
  # @@default_encoders afterwards leaves default_encoder_for falling through to
  # the first *loaded* encoder -- Oj, since it comes first in the registry. So
  # every test after that one silently ran on Oj no matter what TSENCODER said,
  # and whether it happened at all depended on the random seed.
  #
  # Snapshot and restore around every test instead, so order cannot matter.
  setup do
    @__default_encoders = TurboStreamer.class_variable_get(:@@default_encoders).dup
    @__encoder_options  = TurboStreamer.class_variable_get(:@@encoder_options).dup
    @__key_formatter    = TurboStreamer.class_variable_get(:@@key_formatter)
  end

  teardown do
    TurboStreamer.class_variable_set(:@@default_encoders, @__default_encoders)
    TurboStreamer.class_variable_set(:@@encoder_options, @__encoder_options)
    TurboStreamer.class_variable_set(:@@key_formatter, @__key_formatter)
  end

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
