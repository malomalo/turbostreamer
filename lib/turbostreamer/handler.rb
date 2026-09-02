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
      # A layout renders first and threads its builder through the view so the
      # template it wraps writes into the same stream instead of starting one of
      # its own. Locals can't carry it the way partial! does: a top-level
      # template is compiled with `locals: []`, so a `json` local never binds.
      #
      # this juggling is required to keep line numbers right in the error
      %{__already_defined = defined?(json) || (@_turbostreamer_builder && "layout"); json||=@_turbostreamer_builder||TurboStreamer::Template.new(self, output_buffer: TurboStreamer::ActionView::Buffer.wrap(output_buffer)); #{source}
        json.target! unless (__already_defined && __already_defined != "method")}
    end
    
  end
end