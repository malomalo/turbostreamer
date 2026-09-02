# frozen_string_literal: true

class TurboStreamer
  # Prepended to ActionView::StreamingTemplateRenderer by the railtie.
  #
  # ActionView's own streaming renders the *layout* and buffers the template
  # into a string for it, which would defeat the point here -- the whole JSON
  # document would be built in memory before a byte was written. So streamer
  # templates take their own path, writing to the client as the encoder
  # produces bytes.
  module StreamingTemplateRendererExtension

    def render_template(view, template, layout_name = nil, locals = {})
      template_supports_streaming = (layout_name && template.supports_streaming?) || template.handler == TurboStreamer::Handler
      return render_without_streaming(view, template, layout_name, locals) unless layout_name && template_supports_streaming

      locals ||= {}
      layout = find_layout(layout_name, locals.keys, [formats.first])
      log_skipped_layout(layout_name) if layout.nil?

      ActionView::StreamingTemplateRenderer::Body.new do |buffer|
        if template.handler == TurboStreamer::Handler
          delayed_render_json(buffer, template, layout, view, locals)
        else
          delayed_render(buffer, template, layout, view, locals)
        end
      end
    end

    private

      # Deliberately not `super`. Prepending puts ActionView's own streaming
      # render_template next in the chain, and for a streamer template that
      # takes the ERB streaming path. What is wanted is the plain
      # TemplateRenderer implementation -- which TemplateRendererExtension
      # fronts, so the layout handling still applies -- wrapped as a Rack body.
      def render_without_streaming(view, template, layout_name, locals)
        rendered = ActionView::TemplateRenderer
          .instance_method(:render_template)
          .bind_call(self, view, template, layout_name, locals)

        [rendered.body]
      end

      def delayed_render_json(buffer, template, layout, view, locals)
        # Wrap the given buffer in the StreamingBuffer and pass it to the
        # underlying template handler. Now, every time something is concatenated
        # to the buffer, it is not appended to an array, but streamed straight
        # to the client.
        output  = TurboStreamer::StreamingBuffer.new(buffer)
        yielder = lambda { |*name| view._layout_for(*name) }

        ActiveSupport::Notifications.instrument(
          "render_template.action_view",
          identifier: template.identifier,
          layout: layout && layout.virtual_path,
          locals: locals
        ) do
          if layout
            render_json_layout(output, template, layout, view, locals, yielder)
          else
            template.render(view, locals, output, &yielder)
          end
        end
      end

      def render_json_layout(output, template, layout, view, locals, yielder)
        TurboStreamer::Template.render_with_layout(view, layout, locals, output) do
          template.render(view, locals, output, &yielder)
        end
      end

  end
end
