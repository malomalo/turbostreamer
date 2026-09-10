require 'test_helper'

# Where `cache!` sits relative to a key, and what ends up in the cache.
#
# In map context a cached fragment used to have to be a *pair sequence*
# (`"a":1`), because injected bytes went around the encoder and the colon a key
# needs was never written. `cache!` under a key therefore failed. It now works:
# `inject` recognises value position and lets the writer place the fragment,
# which means the cached bytes are a bare value and carry no position with them.
#
# Both encoders agree on every arrangement here, and cache the same bytes, so
# nothing below is encoder-specific.
#
# Every test logs the template, the result and the cache. Run one encoder:
#
#   bundle exec rake test:oj     test/turbo_streamer/cache_shape_test.rb
#   bundle exec rake test:wankel test/turbo_streamer/cache_shape_test.rb

# Defined here rather than relying on template_test.rb's copy, so this file
# runs on its own.
module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

class TurboStreamer::CacheShapeTest < ActiveSupport::TestCase

  class FakeController
    def perform_caching = true
    def instrument_fragment_cache(_name, _key) = yield
  end

  # Deliberately does not respond to cache_fragment_name, so keys stay bare and
  # the cached bytes below are easy to read.
  class FakeContext
    def controller = @controller ||= FakeController.new
  end

  setup do
    Rails.cache.clear
  end

  def encoder
    TurboStreamer.encoder_symbol_for(:json, TurboStreamer.default_encoder_for(:json))
  end

  def fragments
    Rails.cache.instance_variable_get(:@data).values.map { |e| e.value rescue e }
  end

  def render(&block)
    TurboStreamer::Template.new(FakeContext.new, &block).target!.strip
  end

  # --- pair sequences: cache! covering the key and its value ----------------

  test 'cache! over a key and its value caches a pair sequence' do
    out = render { |json| json.object! { json.cache!('k') { json.a 1 } } }
    assert_equal({'a' => 1}, JSON.parse(out))
    assert_equal ['"a":1'], fragments, 'the key is part of the cached bytes'

    out = render { |json| json.object! { json.cache!('k') { json.a 999 } } }
    assert_equal({'a' => 1}, JSON.parse(out), 'the hit replayed the cached fragment')
  end

  # --- values: cache! under a key -------------------------------------------

  test 'cache! under a key caches a bare value, and the fragment carries no colon' do
    body = ->(json) { json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } } } }
    
    assert_equal({'author' => {'a' => 1}}, JSON.parse(render(&body)))
    assert_equal ['{"a":1}'], fragments,
      'a value, not a pair sequence, and no leading colon -- so it is not tied to this position'

    assert_equal({'author' => {'a' => 1}}, JSON.parse(render(&body)), 'the hit path agrees with the miss path')
  end

  test 'a sibling key after a cached one, on both miss and hit' do
    body = ->(json) { json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } }; json.z 2 } }

    assert_equal({'author' => {'a' => 1}, 'z' => 2}, JSON.parse(render(&body)))
    assert_equal({'author' => {'a' => 1}, 'z' => 2}, JSON.parse(render(&body)))
  end

  test 'two cached keys side by side' do
    body = ->(json) do
      json.object! do
        json.a1 { json.cache!('k1') { json.object! { json.a 1 } } }
        json.a2 { json.cache!('k2') { json.object! { json.b 2 } } }
      end
    end

    assert_equal({'a1' => {'a' => 1}, 'a2' => {'b' => 2}}, JSON.parse(render(&body)))
    assert_equal ['{"a":1}', '{"b":2}'], fragments.sort
    assert_equal({'a1' => {'a' => 1}, 'a2' => {'b' => 2}}, JSON.parse(render(&body)))
  end

  test 'a cached scalar under a key' do
    body = ->(json) { json.object! { json.n { json.cache!('k') { json.value! 42 } } } }

    assert_equal({'n' => 42}, JSON.parse(render(&body)))
    assert_equal ['42'], fragments
    assert_equal({'n' => 42}, JSON.parse(render(&body)))
  end

  test 'cache! nested inside a cached value' do
    body = ->(json) do
      json.object! { json.o { json.cache!('k') { json.object! { json.inner { json.cache!('k2') { json.object! { json.a 1 } } } } } } }
    end

    assert_equal({'o' => {'inner' => {'a' => 1}}}, JSON.parse(render(&body)))
    assert_equal({'o' => {'inner' => {'a' => 1}}}, JSON.parse(render(&body)))
  end

  # --- inject! directly -----------------------------------------------------

  test 'inject! supplies a value under a key' do
    out = render { |json| json.object! { json.author { json.inject!('{"a":1}') }; json.z 2 } }

    assert_equal({'author' => {'a' => 1}, 'z' => 2}, JSON.parse(out))
  end

  test 'inject! still supplies pairs to an open map' do
    out = render { |json| json.object! { json.inject!('"a":1'); json.z 2 } }

    assert_equal({'a' => 1, 'z' => 2}, JSON.parse(out))
  end

  # --- fragments are portable between encoders ------------------------------

  test 'a fragment cached under a key replays without its position' do
    body = ->(json) { json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } } } }
    
    key = ActiveSupport::Cache.expand_cache_key('k', :streamer)
    Rails.cache.write(key, '{"a":1}')

    assert_equal({'author' => {'a' => 1}}, JSON.parse(render(&body)),
      'a bare value works wherever a value is expected, whichever encoder wrote it')
  end

end
