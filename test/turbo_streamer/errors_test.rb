require 'test_helper'

class TurboStreamer::ErrorsTest < ActiveSupport::TestCase

  test 'a key with no value raises' do
    error = assert_raises(::ArgumentError) do
      jbuild do |json|
        json.object! { json.foo }
      end
    end

    assert_equal "No value given for `foo`.", error.message
  end

  test 'set! with no value raises' do
    error = assert_raises(::ArgumentError) do
      jbuild do |json|
        json.object! { json.set! :foo }
      end
    end

    assert_equal "No value given for `foo`.", error.message
  end

  test 'child! with no value raises' do
    error = assert_raises(::ArgumentError) do
      jbuild do |json|
        json.array! { json.child! }
      end
    end

    assert_equal "No value given for `child!`.", error.message
  end

  # Untested before this PR, and the message never named the mime type.
  test 'a mime type with no loadable encoder raises' do
    error = assert_raises(::ArgumentError) do
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
