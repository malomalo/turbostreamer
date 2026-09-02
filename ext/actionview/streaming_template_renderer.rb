# frozen_string_literal: true

module ActionView
  class StreamingTemplateRenderer < TemplateRenderer
    
    def render_template(view, template, layout_name = nil, locals = {}) #:nodoc:
      template_supports_streaming = (layout_name && template.supports_streaming?) || template.handler == TurboStreamer::Handler
      return [super.body] unless layout_name && template_supports_streaming

      locals ||= {}
      layout   = layout_name && find_layout(layout_name, locals.keys, [formats.first])

      Body.new do |buffer|
        if template.handler == TurboStreamer::Handler
          delayed_render_json(buffer, template, layout, view, locals)
        else
          delayed_render(buffer, template, layout, view, locals)
        end
      end
    end

    private

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

      # Renders the layout, and lets its `json.yield!` render the template into
      # the same builder. Both write to one encoder, so the template's JSON
      # lands where the layout yielded with its commas and nesting intact --
      # nothing is buffered into a string and spliced back in.
      def render_json_layout(output, template, layout, view, locals, yielder)
        view.instance_variable_set(:@_turbostreamer_content, lambda do |json|
          # Single use: a stream can't be replayed, so a second yield! -- or one
          # from inside the template itself, which would recurse forever --
          # raises rather than rendering twice.
          view.instance_variable_set(:@_turbostreamer_content, nil)
          begin
            view.instance_variable_set(:@_turbostreamer_builder, json)
            template.render(view, locals, output, &yielder)
          ensure
            view.instance_variable_set(:@_turbostreamer_builder, nil)
          end
        end)

        layout.render(view, locals, output, &yielder)
      ensure
        view.instance_variable_set(:@_turbostreamer_content, nil)
      end

  end
end