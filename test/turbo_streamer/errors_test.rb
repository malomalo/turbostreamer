require 'test_helper'

class TurboStreamer::ErrorsTest < ActiveSupport::TestCase

  test 'a key with no value raises' do
    error = assert_raises(TurboStreamer::MissingValueError) do
      jbuild do |json|
        json.object! { json.foo }
      end
    end

    assert_equal "No value given for `foo`.", error.message
  end

  test 'set! with no value raises' do
    error = assert_raises(TurboStreamer::MissingValueError) do
      jbuild do |json|
        json.object! { json.set! :foo }
      end
    end
    
    assert_equal "No value given for `foo`.", error.message
  end

  test 'child! with no value raises' do
    error = assert_raises(TurboStreamer::MissingValueError) do
      jbuild do |json|
        json.array! { json.child! }
      end
    end

    assert_equal "No value given for `child!`.", error.message
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

  test 'two values in a row raise' do
    assert_raises(StandardError) do
      jbuild { |json| json.object! {
        json.key! :a; json.value! 'b'; json.value! 'c'
      } }
    end
  end

  test 'a value emitted without a key raises' do
    assert_raises(StandardError) do
      jbuild { |json| json.object! { json.value! '1' } }
    end
  end

  # The Wankel check is scoped to the direct value call: the base class
  # writes a Hash's own keys through string(), which does not pass through
  # key(), so its recursion into value() has no pending key to see.
  test 'a Hash value is not mistaken for a value without a key' do
    assert_json({'foo' => {'a' => 1}}) do |json|
      json.object! { json.foo({a: 1}) }
    end
  end

  test 'a deeply nested Hash value is not mistaken for one' do
    assert_json({'foo' => {'a' => {'b' => [1, {'c' => nil}]}}}) do |json|
      json.object! { json.foo({a: {b: [1, {c: nil}]}}) }
    end
  end
end
