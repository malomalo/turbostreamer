# frozen_string_literal: true

class TurboStreamer
  # Prepended rather than reopened so `super` still reaches ActionView's own
  # render_template -- everything that isn't a streamer template with a layout
  # falls straight through to it.
  module TemplateRendererExtension

    private

      # ActionView renders the template into a string first and then hands that
      # string to the layout. That works for ERB, where the layout concatenates
      # text, but not for JSON: splicing an encoded document into a keyed slot
      # isn't something either encoder can do -- Oj raises "Can not pop after
      # writing a key but no value", and Wankel has no raw-JSON entry point.
      #
      # So for streamer templates the order is reversed. The layout renders
      # first and its `json.yield!` renders the template into the layout's own
      # builder, which is what the streaming renderer does too.
      def render_template(view, template, layout_name, locals)
        return super unless template.respond_to?(:handler) && template.handler == TurboStreamer::Handler

        layout = layout_name && find_layout(layout_name, locals.keys, [formats.first])
        return super if layout.nil?

        body = ActiveSupport::Notifications.instrument(
          "render_template.action_view",
          identifier: template.identifier,
          layout: layout.virtual_path,
          locals: locals
        ) do
          ActiveSupport::Notifications.instrument(
            "render_layout.action_view",
            identifier: layout.identifier
          ) do
            TurboStreamer::Template.render_with_layout(view, layout, locals) do
              template.render(view, locals) { |*name| view._layout_for(*name) }
            end
          end
        end

        build_rendered_template(body, template)
      end

  end
end

ActionView::TemplateRenderer.prepend(TurboStreamer::TemplateRendererExtension)
