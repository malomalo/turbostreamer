# frozen_string_literal: true

class TurboStreamer

  # Base for everything this library raises, so a caller can rescue the lot
  # without naming each one.
  class Error < ::StandardError
  end

  # A key given nothing to hold: `json.foo` with no value, block or
  # attributes. It used to reach the encoder with the BLANK sentinel, which
  # Oj wrote out as the inspected Object -- memory address and all -- and
  # Wankel raised NoMethodError over.
  class NoValueError < Error
    def self.build(key)
      new("No value given for `#{key}`.")
    end
  end

  # A call this library cannot make sense of. Note that this shadows
  # ::ArgumentError for any code inside `class TurboStreamer`, which is where
  # every raise site lives -- reach for `::ArgumentError` explicitly if Ruby's
  # is ever what is wanted there.
  class ArgumentError < Error
    # json.comments(@cs, :body) { |c| ... } -- attributes to pluck and a block
    # both say how to render each element, and only one can win. The block
    # did, silently, so the attributes were a typo that looked like it worked.
    def self.attributes_with_block(attributes)
      new("Attributes #{attributes.inspect} were given along with a block. " \
          "Both say how to render each element, so pass one or the other.")
    end

    # merge! splices a Hash's pairs or an Array's elements into the document.
    # Anything else has neither to give.
    def self.unmergeable(value)
      new("Can't merge #{value.inspect} which isn't Hash or Array")
    end

    # No encoder for the mime type could be loaded.
    def self.no_encoder(mime)
      new("Could not find an encoder for #{mime.inspect}")
    end
  end

end
