# frozen_string_literal: true

require "turbostreamer"
require "active_support/core_ext"

# This module makes TurboStreamer work with Rails using the template handler
# API.
class TurboStreamer
  class Handler
    
    class_attribute :default_format
    self.default_format = :json
    
    def self.supports_streaming?
      true
    end
    
    def self.call(template, source)
      # A layout renders first and its `yield` renders the template it wraps
      # into the layout's own builder, handed over as the `json` local -- the
      # same way partial! passes it.
      #
      # this juggling is required to keep line numbers right in the error
      %{__already_defined = defined?(json); json||=TurboStreamer::Template.new(self, output_buffer: ActionView::TurboBuffer.wrap(output_buffer)); #{source}
        json.target! unless (__already_defined && __already_defined != "method")}
    end
    
  end
end