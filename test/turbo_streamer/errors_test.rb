require 'test_helper'

class TurboStreamer::ErrorsTest < ActiveSupport::TestCase

  test 'a key with no value raises' do
    error = assert_raises(TurboStreamer::NoValueError) do
      jbuild do |json|
        json.object! { json.foo }
      end
    end

    assert_equal "No value given for `foo`.", error.message
  end

  test 'set! with no value raises' do
    error = assert_raises(TurboStreamer::NoValueError) do
      jbuild do |json|
        json.object! { json.set! :foo }
      end
    end

    assert_equal "No value given for `foo`.", error.message
  end

  test 'child! with no value raises' do
    error = assert_raises(TurboStreamer::NoValueError) do
      jbuild do |json|
        json.array! { json.child! }
      end
    end

    assert_equal "No value given for `child!`.", error.message
  end

  # The point of the hierarchy: one rescue for anything this library raises.
  test 'every error this library raises is a TurboStreamer::Error' do
    [
      -> { jbuild { |json| json.object! { json.foo } } },
      -> { jbuild { |json| json.object! { json.foo([1], :a) { } } } },
      -> { jbuild { |json| json.object! { json.merge!(Set.new) } } },
      -> { TurboStreamer.default_encoder_for(:xml) },
    ].each do |call|
      assert_raises(TurboStreamer::Error) { call.call }
    end
  end

  # This one used to be Ruby's ::ArgumentError and is now ours, by way of the
  # shadowing inside `class TurboStreamer`.
  test 'a mime type with no loadable encoder raises' do
    error = assert_raises(TurboStreamer::ArgumentError) do
      TurboStreamer.default_encoder_for(:xml)
    end

    assert_equal 'Could not find an encoder for :xml', error.message
  end

  test 'a key with an explicit nil value is still allowed' do
    assert_json({'foo' => nil}) do |json|
      json.object! { json.foo nil }
    end
  end

  test 'a key with false is not mistaken for a missing value' do
    assert_json({'foo' => false}) do |json|
      json.object! { json.foo false }
    end
  end

end
