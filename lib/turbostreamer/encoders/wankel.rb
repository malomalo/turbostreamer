# frozen_string_literal: true

require 'wankel'

class TurboStreamer
  class WankelEncoder < ::Wankel::StreamEncoder

    def initialize(io, options={})
      @stack = []
      @populated = []
      @awaiting_value = false
      @writing_value = false

      super(io, {mode: :as_json}.merge(options))
    end

    # Yajl does not check the shape of what it is given the way Oj's writer
    # does -- a key emitted into an array, or a key never given a value, came
    # out as malformed JSON rather than an error. Check here so both encoders
    # refuse the same things.
    # Yajl reports nothing about shape, so these are ours to describe. Kept
    # here rather than in a shared error class because the context comes from
    # @stack, which is this encoder's own state.
    def structure_error(what, context = @stack.last)
      where = case context
              when :array       then 'inside an array'
              when :map         then 'inside a map'
              when :pending_key then 'directly after a key, which is still waiting for its value'
              when nil          then 'at the top level'
              else                   "inside #{context}"
              end

      ::ArgumentError.new("Cannot write #{what} #{where}")
    end

    def key(k)
      if @stack.last != :map
        raise structure_error('a key')
      end
      if @awaiting_value
        raise structure_error('a second key', :pending_key)
      end

      @awaiting_value = true
      string(k)
    end

    def value(v)
      if @stack.last == :map && !@awaiting_value && !@writing_value
        raise structure_error('a value without a key')
      end

      # @stack only ever holds :map or :array, so this is just depth > 0.
      @populated[-1] = true unless @stack.empty?
      @awaiting_value = false
      @writing_value = true

      super
    ensure
      @writing_value = false
    end

    def map_open
      @awaiting_value = false
      @stack << :map
      @populated << false
      super
    end

    def map_close
      if @awaiting_value
        raise structure_error('the end of an object', :pending_key)
      end
      @populated.pop

      @stack.pop
      super
      @populated[-1] = true if @stack.last
    end

    def array_open
      @awaiting_value = false
      @stack << :array
      @populated << false
      super
    end

    def array_close
      @populated.pop
      @stack.pop
      super
      @populated[-1] = true if @stack.last
    end

    def inject(string)
      flush

      # A key is written and its value is what is being injected: the colon is
      # ours, since these bytes never reach yajl.
      if @awaiting_value
        self.output.write(':'.freeze)
        # yajl only needs walking past the value if the capture below did not
        # already do it. On a cache hit no capture ran.
        advance_yajl(1)
        @awaiting_value = false
        return self.output.write(string)
      end

      # Otherwise these are pairs joining an open map, or elements joining an
      # open array. yajl neither delimits them nor counts them, and it only has
      # to be pushed past empty once per container: after that its count is
      # non-zero, so it delimits its own elements and the separator before an
      # injected one is ours. Walking it through an element -- one value for an
      # array, a key and a value for a map -- into a buffer that is thrown away
      # is what advances it.
      case @stack.last
      when :array
        if @populated.last
          self.output.write(',')
        else
          advance_yajl(1)
        end
        @populated[-1] = true
      when :map
        if @populated.last
          self.output.write(',')
        else
          advance_yajl(2)
        end
        @populated[-1] = true
      end

      self.output.write(string)
    end

    def capture(to=nil)
      # Bytes owed from before the capture belong to the document rather than
      # to the fragment -- including the colon yajl emits for a pending key.
      flush

      old_output = self.output
      buffer = to || ::StringIO.new
      tee = ::TurboStreamer::Tee.new(old_output)
      tee.push(buffer)
      self.output = tee

      begin
        yield
        flush
      ensure
        self.output = old_output
      end

      result = buffer.string
      # The colon and any delimiter belong to the position this was rendered
      # in, not to the fragment, so a replay elsewhere must not carry them.
      result.delete_prefix!(':')
      result.delete_prefix!(',')
      result.delete_suffix!(",")
      result
    end

    private

    # Walks yajl through `count` values into a buffer that is thrown away, so
    # its own element count moves on without those bytes reaching the document.
    # A fragment spliced in on a cache hit was never rendered through yajl, so
    # this is what stops yajl emitting a second colon or missing a delimiter.
    def advance_yajl(count)
      flush
      old_output = self.output
      self.output = ::StringIO.new
      count.times { string("".freeze) }
      flush
    ensure
      self.output = old_output
    end

  end
end
