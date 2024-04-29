# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)


require "active_support"

require 'action_view'
require 'action_view/testing/resolvers'

require 'turbostreamer'
require 'turbostreamer/handler'
require 'turbostreamer/template'

require File.expand_path('../../ext/actionview/buffer', __FILE__)
require File.expand_path('../../ext/actionview/streaming_template_renderer', __FILE__)

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
