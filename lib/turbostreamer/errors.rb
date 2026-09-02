# frozen_string_literal: true

class TurboStreamer
  module Errors
    class MergeError < ::StandardError
      def self.build(updates)
        new("Can't merge #{updates.inspect} which isn't Hash or Array")
      end
    end

    class NoTemplateToYieldError < ::StandardError
      def self.build
        new("`yield!` was called outside a layout, so there is no template to render")
      end
    end

    class YieldError < ::StandardError
      def self.build
        new("use `json.yield!` in a .json.streamer layout, `yield` is not supported")
      end
    end
  end
end
