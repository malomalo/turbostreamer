require 'test_helper'

class TurboStreamer::IntegrationTest < ActiveSupport::TestCase

  test 'support unicode string with action view output buffer' do
    output_buffer = ::ActionView::OutputBuffer.new
    string        = "香港"

    assert_equal(::Encoding::UTF_8, output_buffer.encoding)
    assert_equal(::Encoding::UTF_8, string.encoding)

    output_buffer.safe_concat(string)

    assert_equal(::Encoding::UTF_8, output_buffer.encoding)
    assert_equal(::Encoding::UTF_8, string.encoding)

    output_buffer.write(string)

    assert_equal(::Encoding::UTF_8, output_buffer.encoding)
    assert_equal(::Encoding::UTF_8, string.encoding)


    output_buffer = ::ActionView::OutputBuffer.new
    tstreamer = ::TurboStreamer.new(
      output_buffer: output_buffer,
    )
    tstreamer.object! do
      tstreamer.key!("some_key")
      tstreamer.value!(string)
    end

    assert_equal(::Encoding::UTF_8, string.encoding)
    assert_equal(::Encoding::UTF_8, output_buffer.encoding)
  end

end
