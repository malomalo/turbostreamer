$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'active_support'
require "active_support/core_ext"
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_controller'

# Fragment caching is driven by PERFORM_CACHING so the suite can be run both
# ways. It has to be set in two places or the comparison is not like for like:
# turbostreamer and jbuilder ask the controller they are rendered with, while
# rabl consults ActionController::Base.perform_caching by way of
# Rabl::Helpers#template_cache_configured?.
PERFORM_CACHING = ENV.fetch('PERFORM_CACHING', 'true') == 'true'
ActionController::Base.perform_caching = PERFORM_CACHING

class FakeController
  def perform_caching
    PERFORM_CACHING
  end

  def instrument_fragment_cache(a, b)
    yield
  end
end

class FakeContext
  attr_reader :controller

  def initialize
    @controller = FakeController.new
  end
end

struct = Struct.new(:name, :birthyear, :bio, :url)
$author = struct.new("Rolf", 1920, "Software developer", "http://example.com/")
$author.instance_eval { undef each } # Jbuilder doesn't like #each on non-arrays.
$now = Time.now
$arr = 100.times.to_a

# Values outside the cached fragment, so no implementation can serve the whole
# document from cache. A response that is entirely cacheable would be cached at
# the controller instead of rendered, so the interesting case is a cached
# fragment with live data around it.
$request_id = 0
$next_request_id = -> { $request_id += 1 }
