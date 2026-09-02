# frozen_string_literal: true

class TurboStreamer
  module TemplateRendererExtension

    private

      # ActionView renders the template into a string first and then hands that
      # string to the layout. That works for ERB, where the layout concatenates
      # text.
      #
      # For streamer templates the order is reversed. The layout renders first
      # and its `json.yield!` renders the template into the layout's own builder,
      # which is what the streaming renderer does too.
      def render_template(view, template, layout_name, locals)
        return super unless layout_name && template.respond_to?(:handler) && template.handler == TurboStreamer::Handler

        # find_layout returns nil when the layout exists in another format but
        # not this one -- an app with layouts/application.html.erb and no JSON
        # layout. It only raises MissingTemplate when there is no layout by that
        # name in any format.
        layout = find_layout(layout_name, locals.keys, [formats.first])
        return super unless layout

        body = ActiveSupport::Notifications.instrument(
          "render_layout.action_view",
          identifier: layout.identifier
        ) do
          TurboStreamer::Template.render_with_layout(view, layout, locals) do
            ActiveSupport::Notifications.instrument(
              "render_template.action_view",
              identifier: template.identifier,
              layout: layout.virtual_path,
              locals: locals
            ) do
              template.render(view, locals) { |*name| view._layout_for(*name) }
            end
          end
        end

        build_rendered_template(body, template)
      end

  end
end

ActionView::TemplateRenderer.prepend(TurboStreamer::TemplateRendererExtension)
