require 'turbostreamer'
require 'turbostreamer/handler'
require 'turbostreamer/template'
TurboStreamer.set_default_encoder(:json, :oj)

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

def render_turbostreamer
  TurboStreamer::Template.encode FakeContext.new do |json|
    json.object! do
      json.generated_at $now
      json.request_id $next_request_id.call

      json.cache! 'article_fragment' do
        json.article do
          json.object! do
            json.author do
              json.object! do
                json.extract!($author, :name, :birthyear, :bio)
              end
            end
            json.title "Profiling Jbuilder"
            json.body "How to profile Jbuilder"
            json.date $now
            json.references $arr do |ref|
              json.object! do
                json.name "Introduction to profiling"
                json.url "http://example.com/"
              end
            end
            json.comments $arr do |comment|
              json.object! do
                json.author($author, :name, :birthyear, :bio)
                json.email "rolf@example.com"
                json.body "Great article"
                json.date $now
              end
            end
          end
        end
      end

      json.total_comments $arr.size
    end
  end
end

# Fill the cache
render_turbostreamer

__SETUP__

render_turbostreamer
