# frozen_string_literal: true

  # The encoders -- and the C extensions behind them, Oj::StreamWriter and
# Wankel::StreamEncoder -- write their output with the IO-style `write`.
# ActionView's buffers only expose `<<` / `concat` / `safe_concat`, so they
# have to be adapted before an encoder can stream into one.
#
# Subclassing OutputBuffer means this *is* one: Template#render finishes with
# `result.is_a?(OutputBuffer) ? result.to_s : result`, so target! can hand it
# back directly instead of unwrapping. It takes over the String the given
# buffer was writing to rather than keeping one of its own, so the inherited
# methods all report on the same content and there is nothing to delegate.
#
# See StreamingTurboBuffer for the streaming counterpart.
class ActionView::TurboBuffer < ActionView::OutputBuffer

  # instance_of? rather than is_a?, since this class is itself an
  # OutputBuffer and must not be wrapped a second time.
  def self.wrap(buffer)
    if buffer.instance_of?(ActionView::OutputBuffer)
      ActionView::TurboBuffer::new(buffer.raw_buffer)
    elsif buffer.instance_of?(ActionView::StreamingBuffer)
      ActionView::StreamingTurboBuffer.new(buffer.block)
    elsif buffer.respond_to?(:write)
      buffer
    else
      raise ArgumentError, "#{buffer.class} has no #write, so an encoder cannot stream into it"
    end
  end

  def initialize(raw_buffer)
    @raw_buffer = raw_buffer
  end

  # Whatever reaches here is already encoded JSON, so it is appended verbatim
  # instead of being HTML-escaped -- the same thing the old alias did by
  # pointing `write` at `safe_concat`.
  def write(value)
    string = value.to_s
    @raw_buffer << string
    string.bytesize
  end

end
