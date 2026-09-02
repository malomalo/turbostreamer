# frozen_string_literal: true

class TurboStreamer
  module ActionView

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
    # It subclasses ::ActionView::OutputBuffer so that it *is* one:
    # Template#render finishes with `result.is_a?(OutputBuffer) ? result.to_s :
    # result`, so target! can hand this back directly instead of unwrapping.
    # The content lives in the wrapped buffer, not in the inherited one, so
    # to_s is delegated -- as is anything else a caller might read.
    #
    # See TurboStreamer::StreamingBuffer for the streaming counterpart.
    class Buffer < ::ActionView::OutputBuffer

      # Anything that already speaks IO -- a StringIO, a real IO, or a
      # StreamingBuffer -- is handed back untouched.
      def self.wrap(buffer)
        buffer.respond_to?(:write) ? buffer : new(buffer)
      end

      attr_reader :buffer

      def initialize(buffer)
        @buffer = buffer
        super()
      end

      # Whatever reaches here is already encoded JSON, so it is appended
      # verbatim instead of being HTML-escaped -- the same thing the old alias
      # did by pointing `write` at `safe_concat`.
      def write(value)
        string = value.to_s
        @buffer.safe_concat(string)
        string.bytesize
      end

      # Everything below reads through to the wrapped buffer, so an inherited
      # method never reports on the empty buffer this object carries itself.
      def to_s
        @buffer.to_s
      end
      alias_method :html_safe, :to_s

      def to_str
        @buffer.to_str
      end

      def <<(value)
        @buffer << value
        self
      end
      alias_method :concat, :<<
      alias_method :append=, :<<

      def safe_concat(value)
        @buffer.safe_concat(value)
        self
      end
      alias_method :safe_append=, :safe_concat

      def length
        @buffer.length
      end

      def empty?
        @buffer.empty?
      end

    end

  end
end
