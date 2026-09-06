require 'test_helper'

class TurboStreamer::InjectTest < ActiveSupport::TestCase

  test 'support inject! method' do
    result = jbuild do |json|
      json.inject! '{"foo":"bar"}'
    end

    assert_equal({'foo' => 'bar'}, result)
  end

  test 'support inject! method in a block' do
    result = jbuild do |json|
      json.object! do
        json.author do
          json.object! do
            json.inject! '"name":"Pavel"'
          end
        end
      end
    end

    assert_equal 'Pavel', result['author']['name']
  end

  test 'support inject! method in a block with a string with multiple keys' do
    result = jbuild do |json|
      json.object! do
        json.author do
          json.object! do
            json.attr1 "value1"
            json.inject! '"name":"Pavel","age":30'
            json.attr2 "value2"
          end
        end
      end
    end

    assert_equal 'Pavel', result['author']['name']
    assert_equal 30, result['author']['age']
    assert_equal 'value1', result['author']['attr1']
    assert_equal 'value2', result['author']['attr2']
  end

  # The injected bytes go straight to the output, behind the encoder's own
  # bookkeeping, so it does not count them and will not delimit around them.
  # Every arrangement of an injected element next to a rendered one has to come
  # back out as separate elements.

  test 'inject! as the first element of an array, followed by a container' do
    result = jbuild do |json|
      json.array! do
        json.inject! '1'
        json.child! { json.object! { json.a 1 } }
      end
    end

    assert_equal [1, {'a' => 1}], result
  end

  test 'inject! as the first element of an array, followed by a scalar' do
    result = jbuild do |json|
      json.array! do
        json.inject! '1'
        json.child! 2
      end
    end

    assert_equal [1, 2], result
  end

  test 'inject! between two rendered objects in an array' do
    result = jbuild do |json|
      json.array! do
        json.child! { json.object! { json.a 0 } }
        json.inject! '1'
        json.child! { json.object! { json.b 2 } }
      end
    end

    assert_equal [{'a' => 0}, 1, {'b' => 2}], result
  end

  test 'consecutive inject! followed by a container in an array' do
    result = jbuild do |json|
      json.array! do
        json.inject! '1'
        json.inject! '2'
        json.child! { json.object! { json.a 1 } }
      end
    end

    assert_equal [1, 2, {'a' => 1}], result
  end

  test 'inject! followed by a nested array' do
    result = jbuild do |json|
      json.array! do
        json.inject! '1'
        json.child! { json.array! { json.child! 2 } }
      end
    end

    assert_equal [1, [2]], result
  end

  test 'inject! in a map followed by a key with a container value' do
    result = jbuild do |json|
      json.object! do
        json.inject! '"x":1'
        json.y { json.object! { json.z 2 } }
        json.w 3
      end
    end

    assert_equal({'x' => 1, 'y' => {'z' => 2}, 'w' => 3}, result)
  end

  test 'inject! nested inside an injected-into container' do
    result = jbuild do |json|
      json.object! do
        json.inject! '"x":1'
        json.y do
          json.object! do
            json.inject! '"z":2'
            json.w 3
          end
        end
        json.v 4
      end
    end

    assert_equal({'x' => 1, 'y' => {'z' => 2, 'w' => 3}, 'v' => 4}, result)
  end

end
