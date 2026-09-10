# frozen_string_literal: true

class TurboStreamer::Tee

  def initialize(io)
    @targets = [io]
  end

  # Byte count, as IO#write gives, rather than whatever the last target
  # happened to return.
  def write(string)
    @targets.each { |target| target.write(string) }
    string.bytesize
  end

  def push(buffer)
    @targets.push(buffer)
  end

  # Never removes the original target -- a capture only ever pops what it
  # pushed, and this makes losing the real output impossible rather than
  # merely unlikely.
  def pop
    @targets.pop if @targets.size > 1
  end

end