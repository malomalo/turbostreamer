require 'test_helper'
require 'turbostreamer/encoders/oj'

# The railtie gives Oj `mode: :rails` so `<`, `>` and `&` are escaped the way
# ActiveSupport::JSON escapes them, which is what makes a document safe to
# embed in a <script> tag. Nothing covered it, so the mode could have been
# dropped without a test failing.
class TurboStreamer::EscapingTest < ActiveSupport::TestCase

  # Captured at load, before any test can mutate the global encoder options --
  # several tests set them, and the run order is randomised.
  RAILTIE_OJ_OPTIONS = TurboStreamer.default_encoder_options(:oj).dup
  DEFAULT_ENCODER = TurboStreamer.default_encoder_for(:json)

  # These tests set the global options themselves, so put back whatever was
  # there rather than leaving the pollution for whatever runs next.
  setup { @original_oj_options = TurboStreamer.default_encoder_options(:oj).dup }
  teardown { TurboStreamer.set_default_encoder_options(:oj, @original_oj_options) }

  PAYLOAD = '</script><script>alert(1)</script>'
  ESCAPED = '{"body":"\u003c/script\u003e\u003cscript\u003ealert(1)\u003c/script\u003e"}'

  # Driven at the encoder rather than through TurboStreamer.encode, which takes
  # its encoder options from the configured defaults rather than the call.
  def encode_with(options)
    io = StringIO.new
    encoder = TurboStreamer::OjEncoder.new(io, options)
    encoder.map_open
    encoder.key('body')
    encoder.value(PAYLOAD)
    encoder.map_close
    encoder.flush
    io.string.strip
  end

  test 'oj in rails mode escapes HTML entities' do
    json = encode_with(mode: :rails)

    assert_equal ESCAPED, json
    refute_includes json, '<'
    refute_includes json, '>'
  end

  test 'oj outside rails mode does not escape them' do
    assert_includes encode_with(mode: :json), PAYLOAD
  end

  test 'the railtie configures oj with rails mode' do
    skip 'default encoder is not Oj' unless DEFAULT_ENCODER.name == 'TurboStreamer::OjEncoder'

    assert_equal :rails, RAILTIE_OJ_OPTIONS[:mode]
  end

  # Options are stored under the encoder's symbol; naming the class used to
  # find nothing and silently drop the escaping.
  test 'configured options apply whether the encoder is named by symbol or class' do
    TurboStreamer.set_default_encoder_options(:oj, mode: :rails)

    by_symbol = TurboStreamer.encode(encoder: :oj) { |json| json.object! { json.body PAYLOAD } }
    by_class = TurboStreamer.encode(encoder: TurboStreamer::OjEncoder) { |json| json.object! { json.body PAYLOAD } }

    assert_equal ESCAPED, by_symbol.strip
    assert_equal by_symbol, by_class
  end

end
