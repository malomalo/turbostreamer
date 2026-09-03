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
      # A builder passed in `locals` -- by partial!, or by a layout handing its
      # own to the template it wraps -- is written into rather than starting a
      # new one, and target! is left to whoever owns it.
      #
      # Read from local_assigns rather than a `json` local: local_assigns is a
      # parameter of every compiled template, whereas the local only exists if
      # the template declared :json, which a top-level one never does.
      #
      # this juggling is required to keep line numbers right in the error
      %{__parent_json = local_assigns[:json]; json = __parent_json || TurboStreamer::Template.new(self, output_buffer: ActionView::TurboBuffer.wrap(output_buffer)); #{source}
        json.target! unless __parent_json}
    end
    
  end
end