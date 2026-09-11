require 'props_template'
require 'oj'

# Must come after the require: props_template loads its railtie when Rails is
# already defined, and this stub is only here to give the cache somewhere to go.
module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

# props_template's Props::Cache#cache_key calls context.cache_fragment_name
# without a respond_to? guard, where turbostreamer and jbuilder fall back to the
# bare key when the context does not define it. Defined on a subclass rather
# than on the shared FakeContext so the other implementations keep the code path
# they had before this file existed.
class PropsContext < FakeContext
  def cache_fragment_name(key, **options)
    key
  end
end

Props::Template.class_eval do
  def self.encode!(context, options = {})
    json = new(context, options)
    yield json
    json.result!
  end
end

# The cached fragment covers the same subtree as the other implementations, but
# props_template caches internal nodes only -- the value, not the key -- so the
# cached bytes are the article body where turbostreamer's are
# `"article":{...}`. That is each library's own idiom; the emitted document is
# identical.
def render_props_template
  Props::Template.encode!(PropsContext.new) do |json|
    json.generated_at $date
    json.request_id $next_request_id.call

    json.article(cache: 'article_fragment') do
      json.author do
        json.name $author.name
        json.birthyear $author.birthyear
        json.bio $author.bio
      end
      json.title "Profiling Jbuilder"
      json.body "How to profile Jbuilder"
      json.date $date

      json.references do
        json.array! $arr do |ref|
          json.name "Introduction to profiling"
          json.url "http://example.com/"
        end
      end

      json.comments do
        json.array! $arr do |comment|
          json.author do
            json.name $author.name
            json.birthyear $author.birthyear
            json.bio $author.bio
          end
          json.email "rolf@example.com"
          json.body "Great article"
          json.date $date
        end
      end
    end

    json.total_comments $arr.size
  end
end

# Fill the cache
render_props_template

# Everthing before this is run once initially, after is the test
__SETUP__

render_props_template
