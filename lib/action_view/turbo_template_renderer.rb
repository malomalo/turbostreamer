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
              inner_template(template).render(view, locals.merge(json: json))
            end
          end
        end

        build_rendered_template(body, template)
      end

      # A copy of the template that declares :json, so locals can carry the
      # layout's builder into it. The original is compiled with `locals: []`, so
      # a `json` local would never bind and the template would start a builder
      # of its own.
      #
      # Memoized on the original -- which ActionView caches -- because a fresh
      # Template object compiles on every render rather than once.
      def inner_template(template)
        template.instance_variable_get(:@_turbostreamer_inner) ||
          template.instance_variable_set(:@_turbostreamer_inner,
            Template.new(template.source, template.identifier, template.handler,
              format: template.format, virtual_path: template.virtual_path, locals: [:json]))
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
