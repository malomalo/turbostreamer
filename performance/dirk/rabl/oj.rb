require 'oj'
require 'rabl'

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

VIEW_PATH = File.expand_path("../performance/dirk/rabl/views/", __FILE__)
SOURCE = File.read(File.join(VIEW_PATH, "template.rabl"))

# Fill the cache
Rabl::Renderer.new(SOURCE, nil, {format: :json}).render

# Everthing before this is run once initially, after is the test
__SETUP__

Rabl::Renderer.new(SOURCE, nil, {format: :json}).render