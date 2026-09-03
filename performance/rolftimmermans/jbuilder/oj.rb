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

    json.cache! 'article_fragment' do
      json.article do
        json.author($author, :name, :birthyear, :bio)
        json.title "Profiling Jbuilder"
        json.body "How to profile Jbuilder"
        json.date $now
        json.references $arr do |ref|
          json.name "Introduction to profiling"
          json.url "http://example.com/"
        end
        json.comments $arr do |comment|
          json.author($author, :name, :birthyear, :bio)
          json.email "rolf@example.com"
          json.body "Great article"
          json.date $now
        end
      end
    end

    json.total_comments $arr.size
  end
end

# Fill the cache
render_jbuilder

__SETUP__

render_jbuilder
