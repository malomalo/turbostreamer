# frozen_string_literal: true

class TurboStreamer

  # A key given nothing to hold: `json.foo` with no value, block or attributes.
  class NoValueError < ::StandardError
  end

  # A call this library cannot make sense of. Note that this shadows
  # ::ArgumentError for code inside `class TurboStreamer`, which is where every
  # raise site lives -- write `::ArgumentError` where Ruby's is meant.
  class ArgumentError < ::StandardError
  end

end
