$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "active_support"
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_controller'

# Fragment caching is driven by PERFORM_CACHING so the suite can be run both
# ways. turbostreamer, props_template and jbuilder each ask the controller they
# are rendered with (FakeController below).
PERFORM_CACHING = ENV.fetch('PERFORM_CACHING', 'true') == 'true'

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

# Values outside the cached fragment, so no implementation can serve the whole
# document from cache. A response that is entirely cacheable would be cached at
# the controller instead of rendered, so the interesting case is a cached
# fragment with live data around it.
# A fixed, pre-formatted timestamp. Each library would otherwise format
# Time objects with its own encoder policy, producing different bytes and
# doing different amounts of work for the "same" document.
$date = '2015-10-06T21:04:42.000Z'
$request_id = 0
$next_request_id = -> { $request_id += 1 }
