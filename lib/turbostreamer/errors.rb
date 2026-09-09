# frozen_string_literal: true

class TurboStreamer

  # A call this library cannot make sense of: a key given nothing to hold, or
  # arguments that contradict each other. Note that this shadows
  # ::ArgumentError for code inside `class TurboStreamer`, which is where every
  # raise site lives -- write `::ArgumentError` where Ruby's is meant.
  class ArgumentError < ::StandardError
  end

end
