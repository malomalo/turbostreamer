$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "active_support"
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_controller'

# Fragment caching is driven by PERFORM_CACHING so the suite can be run both
# ways. It has to be set in two places or the comparison is not like for like:
# turbostreamer and jbuilder ask the controller they are rendered with, while
# rabl consults ActionController::Base.perform_caching by way of
# Rabl::Helpers#template_cache_configured?. Loading action_view without
# action_controller leaves that check false and silently turns rabl's `cache`
# directive into a no-op while the other two keep caching.
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
