source "https://rubygems.org"

# Specify your gem's dependencies in turbostreamer.gemspec
gemspec

# Only needed by `rake performance`. The group is optional, so a plain
# `bundle install` skips it; run `bundle config set with performance` first.
group :performance, optional: true do
  gem 'analyzer'
  gem 'jbuilder'
  # analyzer runs benchmark-ips with `stats: :bootstrap`, which needs kalibera.
  gem 'kalibera'
  gem 'multi_json'
  gem 'rabl'
end
