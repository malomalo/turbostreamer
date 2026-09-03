# frozen_string_literal: true

class TurboStreamer
  module Errors
    class MergeError < ::StandardError
      def self.build(updates)
        new("Can't merge #{updates.inspect} which isn't Hash or Array")
      end
    end
  end
end
