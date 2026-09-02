# frozen_string_literal: true

class TurboStreamer

  # The encoders -- and the C extensions behind them, Oj::StreamWriter and
  # Wankel::StreamEncoder -- write their output with the IO-style `write`.
  # ActionView's buffers only expose `<<` / `concat` / `safe_concat`, so they
  # have to be adapted before an encoder can stream into one.
  #
  # This used to be done by aliasing `write` onto ActionView::OutputBuffer and
  # ActionView::StreamingBuffer. That worked, but it added a non-escaping
  # append to every buffer in the host application rather than just the ones
  # rendering JSON. Wrapping keeps the shim on objects we own.
  #
  # See TurboStreamer::StreamingBuffer for the streaming counterpart.
  class Buffer

    # Anything that already speaks IO -- a StringIO, a real IO, or a
    # StreamingBuffer -- is handed back untouched.
    def self.wrap(buffer)
      buffer.respond_to?(:write) ? buffer : new(buffer)
    end

    attr_reader :buffer

    def initialize(buffer)
      @buffer = buffer
    end

    # Whatever reaches here is already encoded JSON, so it is appended verbatim
    # instead of being HTML-escaped -- the same thing the old alias did by
    # pointing `write` at `safe_concat`.
    def write(value)
      string = value.to_s
      @buffer.safe_concat(string)
      string.bytesize
    end
    alias_method :<<, :write
    alias_method :concat, :write
    alias_method :safe_concat, :write
    alias_method :append=, :write
    alias_method :safe_append=, :write

    def to_s
      @buffer.to_s
    end

  end

end
