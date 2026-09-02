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
        unless layout
          log_skipped_layout(layout_name)
          return super
        end

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

      # A layout that exists in another format resolves to nil rather than
      # raising, so a layout saved with the wrong extension is skipped with no
      # signal at all. Rails renders bare here and so do we -- an app that
      # declares `layout "application"` explicitly hands us that name on every
      # format, including ones it has no layout for -- but say so.
      #
      # Debug rather than warn: in that same app this fires on every JSON
      # request, and it is only worth reading while you are wondering where
      # your layout went.
      def log_skipped_layout(layout_name)
        logger = ActionView::Base.logger
        return unless logger

        logger.debug do
          "  Skipped layout #{layout_name} -- it does not exist for " \
          "#{formats.first.inspect}; rendering without a layout"
        end
      end

  end
end

ActionView::TemplateRenderer.prepend(TurboStreamer::TemplateRendererExtension)
