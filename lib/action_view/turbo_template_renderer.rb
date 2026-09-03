# frozen_string_literal: true

module ActionView

  # Prepended to TemplateRenderer by the railtie.
  module TurboTemplateRenderer

    private

      # ActionView renders the template into a string first and then hands that
      # string to the layout. That works for ERB, where the layout concatenates
      # text.
      #
      # For streamer templates the order is reversed. The layout renders first
      # and its `yield` renders the template into the layout's own
      # builder, which is what the streaming renderer does too.
      def render_template(view, template, layout_name, locals)
        return super unless template.handler == TurboStreamer::Handler

        # find_layout returns nil when the layout exists in another format but
        # not this one -- an app with layouts/application.html.erb and no JSON
        # layout. It only raises MissingTemplate when there is no layout by
        # that name in any format.
        layout = layout_name && find_layout(layout_name, locals.keys, [formats.first])
        if layout.nil?
          log_skipped_layout(layout_name) if layout_name
          return super
        end

        body = ActiveSupport::Notifications.instrument(
          "render_layout.action_view",
          identifier: layout.identifier
        ) do
          TurboStreamer::Template.render_with_layout(view, layout, locals) do |json|
            ActiveSupport::Notifications.instrument(
              "render_template.action_view",
              identifier: template.identifier,
              layout: layout.virtual_path,
              locals: locals
            ) do
              template.render(view, locals.merge(json: json))
            end
          end
        end

        # render_with_layout hands back its buffer; the caller wants a String.
        build_rendered_template(body.to_s, template)
      end

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
