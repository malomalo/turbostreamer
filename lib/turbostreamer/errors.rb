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

  # Attributes to pluck and a block, given together: `json.comments(@cs,
  # :body) { |c| ... }`. Both say how to render each element and only one can
  # win -- the block did, silently, so the attributes were a typo that looked
  # like it worked.
  class ConflictingArgumentsError < ::StandardError
    def self.build(attributes)
      new("Attributes #{attributes.inspect} were given along with a block. " \
          "Both say how to render each element, so pass one or the other.")
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
