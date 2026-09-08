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

    # Something emitted where the document's shape does not allow it. Oj's
    # writer raises on these itself; this exists so the Wankel encoder can
    # refuse the same shapes instead of writing malformed JSON.
    class StructureError < ::StandardError
      def self.build(what, context)
        where = case context
                when :array        then 'inside an array'
                when :map          then 'inside a map'
                when :pending_key  then 'directly after a key, which is still waiting for its value'
                when nil           then 'at the top level'
                else                    "inside #{context}"
                end
        new("Cannot write #{what} #{where}")
      end
    end
  end
end
