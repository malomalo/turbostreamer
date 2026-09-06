require 'test_helper'

class TurboStreamer::ErrorsTest < ActiveSupport::TestCase

  # A key with nothing after it used to reach the encoder holding the BLANK
  # sentinel: Oj wrote it out as the inspected Object, memory address and all,
  # while Wankel raised NoMethodError on as_json.

  test 'a key with no value raises' do
    error = assert_raises(TurboStreamer::Errors::MissingValueError) do
      jbuild { |json| json.object! { json.foo } }
    end

    assert_match 'foo', error.message
    assert_match 'json.null!', error.message
  end

  test 'set! with no value raises' do
    assert_raises(TurboStreamer::Errors::MissingValueError) do
      jbuild { |json| json.object! { json.set! :foo } }
    end
  end

  test 'child! with no value raises' do
    assert_raises(TurboStreamer::Errors::MissingValueError) do
      jbuild { |json| json.array! { json.child! } }
    end
  end

  test 'a key with an explicit nil value is still allowed' do
    assert_equal({'foo' => nil}, jbuild { |json| json.object! { json.foo nil } })
  end

  test 'a key with false is not mistaken for a missing value' do
    assert_equal({'foo' => false}, jbuild { |json| json.object! { json.foo false } })
  end

  # Oj's writer refuses these itself; the Wankel encoder checks so that both
  # reject the same shapes rather than one of them writing malformed JSON.

  test 'a key emitted inside an array raises' do
    assert_raises(StandardError) do
      jbuild { |json| json.array! { json.merge!({a: 1}) } }
    end
  end

  test 'a key never given a value raises' do
    assert_raises(StandardError) do
      jbuild { |json| json.object! { json.key! :a } }
    end
  end

  test 'two keys in a row raise' do
    assert_raises(StandardError) do
      jbuild { |json| json.object! { json.key! :a; json.key! :b } }
    end
  end

end
