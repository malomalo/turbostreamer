require 'test_helper'
require 'tempfile'

# TurboStreamer prepends itself to ActionView's TemplateRenderer and
# StreamingTemplateRenderer for layouts, so every render in the app passes
# through them, not only streamer ones. render plain:, html:, body: and file:
# get Template::Text, ::HTML and ::RawFile, which have no #handler. They must
# be handed straight back to ActionView.
class RailsIntegration::NonStreamerTemplateTest < ActiveSupport::TestCase

  test "render plain: passes through to ActionView" do
    assert_equal 'complete', render_without_template(plain: 'complete')
  end

  # html: is marked html_safe because ActionView escapes it otherwise, with or
  # without us.
  test "render html: passes through to ActionView" do
    assert_equal '<b>ok</b>', render_without_template(html: '<b>ok</b>'.html_safe)
  end

  test "render body: passes through to ActionView" do
    assert_equal 'complete', render_without_template(body: 'complete')
  end

  # Only file: is tested streaming. ActionView's own StreamingTemplateRenderer
  # asks every template #supports_streaming?, which of these only RawFile
  # defines, so `render stream: true, plain:` raises in Rails with or without
  # us.
  { 'without streaming' => false, 'when streaming' => true }.each do |name, stream|
    test "render file: passes through to ActionView #{name}" do
      Tempfile.create(['raw', '.json']) do |file|
        file.write('{"from":"disk"}')
        file.flush

        assert_equal '{"from":"disk"}', render_without_template(stream: stream, file: file.path)
      end
    end
  end

  private

    # Renders with no template file at all, which ActionView answers with
    # Template::Text, ::HTML or ::RawFile. Goes through
    # StreamingTemplateRenderer when `stream:` is true. Returns the rendered
    # String.
    def render_without_template(stream: false, **options)
      lookup_context = ActionView::LookupContext.new(ActionView::PathSet.new([]), formats: [:json])
      view = ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)

      if stream
        body = ActionView::StreamingTemplateRenderer.new(lookup_context).render(view, **options)
        [].tap { |chunks| body.each { |chunk| chunks << chunk } }.join
      else
        ActionView::TemplateRenderer.new(lookup_context).render(view, **options).body
      end
    end

end
