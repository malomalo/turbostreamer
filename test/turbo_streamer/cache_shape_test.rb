require 'test_helper'

# Where `cache!` sits relative to a key changes what gets cached, and the two
# encoders do not agree about which arrangements are legal. These tests record
# what actually happens rather than what ought to -- including one arrangement
# that succeeds on a cache miss and raises on a hit, which is a bug rather than
# a decision.
#
# The root of it: in map context a cached fragment is a *pair sequence*
# (`"a":1`), not a value. `cache!` is documented as having to cover the key and
# the value together for that reason.
#
# Every test logs the template it renders, what came out, and what landed in
# the cache. Run one encoder at a time:
#
#   bundle exec rake test:oj     test/turbo_streamer/cache_shape_test.rb
#   bundle exec rake test:wankel test/turbo_streamer/cache_shape_test.rb
#
# Set QUIET=1 to silence the logging (worth doing for a full-suite run).

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
    log ''
    log "── #{name}   [encoder: #{encoder}]"
  end

  def log(message)
    puts message unless ENV['QUIET']
  end

  def encoder
    TurboStreamer.encoder_symbol_for(:json, TurboStreamer.default_encoder_for(:json))
  end

  def cached_fragments
    Rails.cache.instance_variable_get(:@data).to_h { |k, e| [k, (e.value rescue e)] }
  end

  # Renders, logging the template, the result and the cache. Returns
  # [output_or_nil, error_or_nil].
  def render_cached(template, label: 'render', &block)
    log "   template: #{template}"
    out = TurboStreamer::Template.new(FakeContext.new, &block).target!.strip
    log "   #{label}: #{out}"
    log "   cached:   #{cached_fragments.inspect}"
    [out, nil]
  rescue StandardError => e
    log "   #{label}: RAISED #{e.class} -- #{e.message.lines.first.strip}"
    log "   cached:   #{cached_fragments.inspect}"
    [nil, e]
  end

  # --- the documented form: cache! covers the key and the value -------------

  DOCUMENTED = "json.object! { json.cache!('k') { json.a 1 } }"

  test 'the documented form caches a pair sequence, and replays it on a hit' do
    out, error = render_cached(DOCUMENTED, label: 'miss') { |json| json.object! { json.cache!('k') { json.a 1 } } }
    assert_nil error
    assert_equal({'a' => 1}, JSON.parse(out))
    assert_equal ['"a":1'], cached_fragments.values, 'the key is part of the cached bytes'

    # Same key, different body: the cached bytes must win.
    out, error = render_cached(DOCUMENTED.sub('1 }', '999 }'), label: 'hit') do |json|
      json.object! { json.cache!('k') { json.a 999 } }
    end
    assert_nil error
    assert_equal({'a' => 1}, JSON.parse(out), 'the hit replayed the cached fragment')
  end

  # --- cache! under a key ---------------------------------------------------

  UNDER_KEY = "json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } } }"

  def render_under_key(label)
    render_cached(UNDER_KEY, label: label) do |json|
      json.object! { json.author { json.cache!('k') { json.object! { json.a 1 } } } }
    end
  end

  test 'cache! under a key is refused by the Oj encoder, on miss and on hit' do
    skip "running #{encoder}" unless encoder == :oj

    _, miss_error = render_under_key('miss')
    _, hit_error  = render_under_key('hit')

    assert_kind_of StandardError, miss_error
    assert_kind_of StandardError, hit_error, 'consistent: refused either way'
  end

  # BUG, not a decision. On a miss `cache!` runs the block, whose `json.object!`
  # calls map_open, which clears @awaiting_value -- so map_close is satisfied.
  # On a hit the block never runs, `inject` does not clear the flag, and
  # map_close raises. In an app that means the first request after a deploy
  # succeeds and every later one fails.
  test 'cache! under a key succeeds on a miss but raises on a hit -- Wankel' do
    skip "running #{encoder}" unless encoder == :wankel

    out, miss_error = render_under_key('miss')
    assert_nil miss_error, 'the miss path succeeds'
    assert_equal({'author' => {'a' => 1}}, JSON.parse(out))
    assert_equal [':{"a":1}'], cached_fragments.values,
      'and caches the colon, so the fragment is only valid in this exact position'

    _, hit_error = render_under_key('hit')
    refute_nil hit_error, 'but the hit path raises -- this is the bug'
    assert_kind_of TurboStreamer::Errors::StructureError, hit_error
  end

  # A pre-seeded fragment cannot rescue the hit path either, whatever shape it
  # has -- the guard fires before the bytes are ever placed.
  test 'no cached fragment shape makes the hit path work -- Wankel' do
    skip "running #{encoder}" unless encoder == :wankel

    key = ActiveSupport::Cache.expand_cache_key('k', :streamer)
    [':{"a":1}', '{"a":1}', '"a":1'].each do |fragment|
      Rails.cache.clear
      Rails.cache.write(key, fragment)
      log "   seeded:   #{fragment.inspect}"
      _, error = render_under_key('hit')
      refute_nil error, "#{fragment.inspect} still raises"
    end
  end

  # --- inject! under a key: refused by both --------------------------------

  test 'inject! under a key is refused by both encoders' do
    _, error = render_cached(%q{json.object! { json.author { json.inject!('{"a":1}') } }}) do |json|
      json.object! { json.author { json.inject!('{"a":1}') } }
    end

    refute_nil error, 'the bytes go around the encoder, so the key never gets its colon'
  end

end
