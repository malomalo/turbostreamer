# frozen_string_literal: true

class TurboStreamer
  module Errors
    class MergeError < ::StandardError
      def self.build(updates)
        new("Can't merge #{updates.inspect} which isn't Hash or Array")
      end
    end

    class LayoutDidNotYieldError < ::StandardError
      def self.build(identifier)
        new("#{identifier} never yielded, so the template it wraps was not " \
            "rendered. Place it with `json.some_key yield`.")
      end
    end

    class ContentAlreadyYieldedError < ::StandardError
      def self.build
        new("the template was already yielded. A stream can't be replayed, so " \
            "a layout can only yield once.")
      end
    end
  end
end
