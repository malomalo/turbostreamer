# frozen_string_literal: true

class TurboStreamer
  module Errors
    class MergeError < ::StandardError
      def self.build(updates)
        message = "Can't merge #{updates.inspect} which isn't Hash or Array"
        new(message)
      end
    end

    class NothingToYieldError < ::StandardError
      def self.build
        new("`yield!` was called outside a layout, so there is no template to render")
      end
    end

    class YieldKeywordError < ::StandardError
      def self.build
        new("use `json.yield!` in a .json.streamer layout, not `yield`. The " \
            "template is written into the stream where it is yielded, so it " \
            "has to be placed by the builder rather than returned as a value.")
      end
    end
  end
end
