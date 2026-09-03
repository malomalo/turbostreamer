# frozen_string_literal: true

class TurboStreamer
  module Errors
    class MergeError < ::StandardError
      def self.build(updates)
        new("Can't merge #{updates.inspect} which isn't Hash or Array")
      end
    end

    class NothingToYieldError < ::StandardError
      def self.build
        new("`yield!` was called outside a layout, so there is no template to render")
      end
    end
  end
end
