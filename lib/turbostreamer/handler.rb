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
      # this juggling is required to keep line numbers right in the error
      %{__parent_json = local_assigns[:json]; json = __parent_json || TurboStreamer::Template.new(self, output_buffer: ActionView::TurboBuffer.wrap(output_buffer)); #{source}
        json.target! unless __parent_json}
    end
    
  end
end