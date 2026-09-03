require 'oj'
require 'rabl'

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end

  # rabl's Engine#cache_key reads this before it will build a cache key.
  def self.version
    ActiveSupport::VERSION::STRING
  end
end

VIEW_PATH = File.expand_path("./performance/dirk/rabl/views/")

# Fill the cache
Rabl::Renderer.new("template", nil, format: :json, view_path: VIEW_PATH).render

# Everthing before this is run once initially, after is the test
__SETUP__

Rabl::Renderer.new("template", nil, format: :json, view_path: VIEW_PATH).render
