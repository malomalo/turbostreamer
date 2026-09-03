# frozen_string_literal: true

module ActionView

  # Prepended to StreamingTemplateRenderer by the railtie.
  #
  # ActionView's own streaming renders the *layout* and buffers the template
  # into a string for it, which would defeat the point here -- the whole JSON
  # document would be built in memory before a byte was written. So streamer
  # templates take their own path, writing to the client as the encoder
  # produces bytes.
  module StreamingTurboTemplateRenderer

    def render_template(view, template, layout_name = nil, locals = {})
      return super unless template.handler == TurboStreamer::Handler

      locals ||= {}
      layout = layout_name && find_layout(layout_name, locals.keys, [formats.first])
      log_skipped_layout(layout_name) if layout_name && layout.nil?

      StreamingTemplateRenderer::Body.new do |buffer|
        delayed_render_json(buffer, template, layout, view, locals)
      end
    end

    private

      def delayed_render_json(buffer, template, layout, view, locals)
        # Wrap the given buffer in the StreamingTurboBuffer and pass it to the
        # underlying template handler. Now, every time something is
        # concatenated to the buffer, it is not appended to an array, but
        # streamed straight to the client.
        output = StreamingTurboBuffer.new(buffer)

        ActiveSupport::Notifications.instrument(
          "render_template.action_view",
          identifier: template.identifier,
          layout: layout && layout.virtual_path,
          locals: locals
        ) do
          if layout
            TurboStreamer::Template.render_with_layout(view, layout, locals, output) do |json|
              inner_template(template).render(view, locals.merge(json: json), output)
            end
          else
            template.render(view, locals, output)
          end
        end
      end

  end

end
