# frozen_string_literal: true

# Rails. 8.1 requires this not sure why we have to load it and the railtie doesn't
require "active_support/core_ext/module/delegation"

require 'rails/railtie'

class TurboStreamer
  class Railtie < ::Rails::Railtie
    initializer :turbostreamer do
      ActiveSupport.on_load :action_view do
        # Require turbostreamer in here so it's only loaded if needed
        require 'turbostreamer'
        require 'turbostreamer/action_view/buffer'
        require 'turbostreamer/action_view/streaming_buffer'
        require 'turbostreamer/action_view/template_renderer'
        require 'turbostreamer/action_view/streaming_template_renderer'

        # Rooted with `::` -- TurboStreamer::ActionView shadows the framework
        # inside this class body.
        ::ActionView::TemplateRenderer.prepend(TurboStreamer::ActionView::TemplateRenderer)
        ::ActionView::StreamingTemplateRenderer.prepend(TurboStreamer::ActionView::StreamingTemplateRenderer)

        # Register Turbostreamer with Rails
        ::ActionView::Template.register_template_handler :streamer, TurboStreamer::Handler
        
        # Setup the default for oj to be rails mode by default unless options
        # have already been set
        if TurboStreamer.default_encoder_for(:json).name == 'TurboStreamer::OjEncoder'
          if !TurboStreamer.has_default_encoder_options?(:oj)
            TurboStreamer.set_default_encoder_options(:oj, mode: :rails)
          end
        end
        
        require 'turbostreamer/dependency_tracker'
      end
    end
  end
end