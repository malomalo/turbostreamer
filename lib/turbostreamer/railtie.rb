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
        require 'action_view/turbo_buffer'
        require 'action_view/streaming_turbo_buffer'
        require 'action_view/turbo_template_renderer'
        require 'action_view/streaming_turbo_template_renderer'

        ActionView::TemplateRenderer.prepend(ActionView::TurboTemplateRenderer)
        ActionView::StreamingTemplateRenderer.prepend(ActionView::StreamingTurboTemplateRenderer)

        # Register Turbostreamer with Rails
        ActionView::Template.register_template_handler :streamer, TurboStreamer::Handler
        
        # Resolve the encoder once, here, the way an app resolves its cache
        # store at boot. Left unset, default_encoder_for falls through to
        # get_encoder on every render, and the `require` in there re-scans
        # $LOAD_PATH each time.
        encoder = TurboStreamer.default_encoder_for(:json)
        TurboStreamer.set_default_encoder(:json, encoder)

        # Oj's :rails mode is what escapes HTML entities the way
        # ActiveSupport::JSON does, so a payload embedded in a <script> tag is
        # safe. Merge rather than skip when options are already set: an app
        # setting an unrelated one -- buffer_size, say -- would otherwise lose
        # the mode along with the escaping, silently. Anything the app set
        # explicitly still wins.
        if encoder.name == 'TurboStreamer::OjEncoder'
          TurboStreamer.set_default_encoder_options(
            :oj, { mode: :rails }.merge(TurboStreamer.default_encoder_options(:oj))
          )
        end
        
        require 'turbostreamer/dependency_tracker'
      end
    end
  end
end