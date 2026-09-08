require 'test_helper'

# Where `cache!` sits relative to a key changes what gets cached, and the two
# encoders do not agree about which arrangements are legal. These tests record
# what actually happens rather than what ought to -- see the divergence at the
# bottom, which is unresolved.
#
# The root of it: in map context a cached fragment is a *pair sequence*
# (`"a":1`), not a value. `cache!` is documented as having to cover the key and
# the value together for that reason.
#
# Run one encoder at a time:
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

  # Deliberately does not respond to cache_fragment_name, so keys are used bare
  # and the cached bytes below are easy to read.
  class FakeContext
    def controller = @controller ||= FakeController.new
  end

  setup { Rails.cache.clear }

  # Returns [rendered, cached_fragments]
  def render_cached(&block)
    Rails.cache.clear
    out = TurboStreamer::Template.new(FakeContext.new, &block).target!
    fragments = Rails.cache.instance_variable_get(:@data).values.map { |e| e.value rescue e }
    [out.strip, fragments]
  end

  def encoder
    TurboStreamer.encoder_symbol_for(:json, TurboStreamer.default_encoder_for(:json))
  end

  # --- the documented form: cache! covers the key and the value -------------

  test 'cache! wrapping a key and its value caches a pair sequence' do
    out, cached = render_cached { |json| json.object! { json.cache!('k') { json.a 1 } } }

    assert_equal({'a' => 1}, JSON.parse(out))
    assert_equal ['"a":1'], cached, 'the key is part of the cached bytes'
  end

  test 'a cached pair sequence replays on a hit' do
    render_cached { |json| json.object! { json.cache!('k') { json.a 1 } } }
    # second render with a different body: the cached bytes win
    out, _ = render_cached do |json|
      Rails.cache.write(ActiveSupport::Cache.expand_cache_key('k', :streamer), '"a":1')
      json.object! { json.cache!('k') { json.a 999 } }
    end

    assert_equal({'a' => 1}, JSON.parse(out))
  end

  # --- cache! under a key: the encoders disagree ----------------------------
  #
  # Oj refuses it. Wankel accepts it and caches a fragment with a leading
  # colon, because its `capture` shares the yajl handle, so yajl emits the `:`
  # for the enclosing key into the capture buffer.

  test 'cache! under a key is refused by the Oj encoder' do
    skip "running #{encoder}" unless encoder == :oj

    assert_raises(StandardError) do
      render_cached { |json| json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } } } }
    end
  end

  test 'cache! under a key is accepted by the Wankel encoder, colon and all' do
    skip "running #{encoder}" unless encoder == :wankel

    out, cached = render_cached { |json| json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } } } }

    assert_equal({'author' => {'a' => 1}}, JSON.parse(out), 'the output happens to be correct')
    assert_equal [':{"a":1}'], cached,
      'but the cached fragment carries the colon, so it is only valid in this exact position'
  end

  test 'cache! under a key wrapping a bare scalar, on Wankel' do
    skip "running #{encoder}" unless encoder == :wankel

    out, cached = render_cached { |json| json.object! { json.author { json.cache!('k') { json.value! 1 } } } }

    assert_equal({'author' => 1}, JSON.parse(out))
    assert_equal [':1'], cached
  end

  # --- inject! under a key: refused by both --------------------------------
  #
  # The bytes go around the encoder, so the colon the key needs is never
  # written. Without a guard Wankel emitted `{"author"{"a":1}}` silently.

  test 'inject! under a key is refused by both encoders' do
    error = assert_raises(StandardError) do
      render_cached { |json| json.object! { json.author { json.inject!('{"a":1}') } } }
    end

    refute_nil error.message
  end

end
