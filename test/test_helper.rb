# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require 'turbostreamer'
require 'turbostreamer/railtie'

require 'action_view'
require 'action_view/testing/resolvers'

require "active_support/testing/autorun"
require 'mocha/minitest'

if ENV["TSENCODER"]
  TurboStreamer.set_default_encoder(:json, ENV["TSENCODER"].to_sym)
end

class ActiveSupport::TestCase

  def jbuild(*args, &block)
    ::JSON.parse(TurboStreamer.encode(*args, &block))
  end

  def assert_json(json, &block)
    assert_equal json, jbuild(&block)
  end

end
