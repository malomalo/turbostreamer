# frozen_string_literal: true

require 'rails/railtie'

class TurboStreamer
  class Railtie < ::Rails::Railtie
    initializer :turbostreamer do
      ActiveSupport.on_load :action_view do
        # Require turbostreamer in here so it's only loaded if needed
        require 'turbostreamer'
        require File.expand_path('../../../ext/actionview/buffer', __FILE__)
        require File.expand_path('../../../ext/actionview/streaming_template_renderer', __FILE__)

        # Register Turbostreamer with Rails
        ActionView::Template.register_template_handler :streamer, TurboStreamer::Handler
        
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