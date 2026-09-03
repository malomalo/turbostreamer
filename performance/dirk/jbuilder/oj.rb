require 'jbuilder'
require 'jbuilder/jbuilder_template'
require 'oj'
require 'multi_json'
MultiJson.use :oj

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

def render_jbuilder
  JbuilderTemplate.encode FakeContext.new do |json|
    json.generated_at $now
    json.request_id $next_request_id.call

    json.cache! 'jbcached' do
      json.cached do
        json.items do
          json.array! 0..100 do |i|
            json.a i
            json.b i
            json.c i
            json.d i
            json.e i

            json.subitems 0..100 do |j|
              json.f i.to_s * j
              json.g i.to_s * j
              json.h i.to_s * j
              json.i i.to_s * j
              json.j i.to_s * j
            end
          end
        end
      end
    end

    json.item_count 101
  end
end

# Fill the cache
render_jbuilder

# Everthing before this is run once initially, after is the test
__SETUP__

render_jbuilder
