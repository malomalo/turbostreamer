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
# cached bytes are `{"items":...}` where turbostreamer's are `"cached":{...}`.
# That is each library's own idiom; the emitted document is identical.
def render_props_template
  Props::Template.encode!(PropsContext.new) do |json|
    json.generated_at $date
    json.request_id $next_request_id.call

    json.cached(cache: 'ptcached') do
      json.items do
        json.array! 0..100 do |i|
          json.a i
          json.b i
          json.c i
          json.d i
          json.e i

          json.subitems do
            json.array! 0..100 do |j|
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
render_props_template

# Everthing before this is run once initially, after is the test
__SETUP__

render_props_template
