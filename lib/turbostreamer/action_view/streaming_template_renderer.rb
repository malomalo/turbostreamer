# frozen_string_literal: true

class TurboStreamer
  module ActionView
    # Prepended to ::ActionView::StreamingTemplateRenderer by the railtie.
    #
    # ActionView's own streaming renders the *layout* and buffers the template
    # into a string for it, which would defeat the point here -- the whole JSON
    # document would be built in memory before a byte was written. So streamer
    # templates take their own path, writing to the client as the encoder
    # produces bytes.
    #
    # Note that inside this namespace a bare `ActionView` resolves here, not to
    # the framework, so references to it are rooted with `::`.
    module StreamingTemplateRenderer

      def render_template(view, template, layout_name = nil, locals = {})
        return super unless template.handler == TurboStreamer::Handler

        locals ||= {}
        layout = layout_name && find_layout(layout_name, locals.keys, [formats.first])
        log_skipped_layout(layout_name) if layout_name && layout.nil?

        ::ActionView::StreamingTemplateRenderer::Body.new do |buffer|
          delayed_render_json(buffer, template, layout, view, locals)
        end
      end

      private

        def delayed_render_json(buffer, template, layout, view, locals)
          # Wrap the given buffer in the StreamingBuffer and pass it to the
          # underlying template handler. Now, every time something is
          # concatenated to the buffer, it is not appended to an array, but
          # streamed straight to the client.
          output  = ::ActionView::StreamingTurboBuffer.new(buffer)
          yielder = lambda { |*name| view._layout_for(*name) }

          ActiveSupport::Notifications.instrument(
            "render_template.action_view",
            identifier: template.identifier,
            layout: layout && layout.virtual_path,
            locals: locals
          ) do
            if layout
              TurboStreamer::Template.render_with_layout(view, layout, locals, output) do
                template.render(view, locals, output, &yielder)
              end
            else
              template.render(view, locals, output, &yielder)
            end
          end
        end

    end
  end
end
