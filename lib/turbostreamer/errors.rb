# frozen_string_literal: true

class TurboStreamer
  # A key given nothing to hold: `json.foo` with no value, block or
  # attributes. It used to reach the encoder with the BLANK sentinel, which
  # Oj wrote out as the inspected Object -- memory address and all -- and
  # Wankel raised NoMethodError over.
  class MissingValueError < ::StandardError
    def self.build(key)
      new("No value given for `#{key}`.")
    end
  end

  module Errors
    class MergeError < ::StandardError
      def self.build(updates)
        new("Can't merge #{updates.inspect} which isn't Hash or Array")
      end
    end
  end
end
