require 'bundler/setup'
require "bundler/gem_tasks"

require 'debug'
require 'fileutils'
require "rake/testtask"

ENCODERS = %w(wankel oj)

# Test Task
ENCODERS.each do |encoder|
  namespace :test do
    Rake::TestTask.new(encoder => ["#{encoder}:env", "test:coverage"]) do |t|
      t.libs << 'lib' << 'test'
      t.test_files = FileList[ARGV[1] ? ARGV[1] : 'test/**/*_test.rb']
      t.warning = true
      t.verbose = false
    end

    namespace encoder do
      task(:env) { ENV["TSENCODER"] = encoder }
    end
  end
end

namespace :test do

  task :coverage do
    require 'simplecov'
    SimpleCov.start do
      add_group 'lib', 'lib'
      add_filter "/test"
    end
  end

  desc "Run test with all encoders"
  task all: ENCODERS.shuffle.map{ |e| "test:#{e}" }

end

task :performance do
  require 'analyzer'

  files = [
    'rabl/oj.rb',
    'jbuilder/oj.rb',
    'turbostreamer/oj.rb',
    'turbostreamer/wankel.rb',
  ]

  # Each suite runs twice. With caching off every implementation rebuilds the
  # document, which compares the builders themselves. With it on, each caches
  # the same fragment while the keys around it stay live -- a response that is
  # cacheable end to end would be cached at the controller rather than rendered,
  # so a cached fragment with live data around it is the case worth measuring.
  suites = { 'rolftimmermans' => '22KB document', 'dirk' => '5MB document' }
  suites.each do |suite, description|
    base = File.expand_path("../performance/#{suite}", __FILE__)
    paths = files.map { |i| File.join(base, i) }

    { 'report-cached.png' => true, 'report-uncached.png' => false }.each do |output, caching|
      ENV['PERFORM_CACHING'] = caching.to_s
      analyzer = Analyzer.new(*paths, lib: File.join(base, 'lib.rb'))
      analyzer.plot(File.join(base, output),
        title: "#{suite} - #{description}, fragment caching #{caching ? 'on' : 'off'}")
    end
  end
ensure
  ENV.delete('PERFORM_CACHING')
end

# alba's benchmark suite, vendored under performance/alba. Shaped differently
# from the Analyzer suites above -- benchmark-ips over ~17 serializers -- and it
# carries its own bundle, so it is a separate task rather than part of
# `rake performance`. See performance/alba/README.md.
namespace :performance do
  desc "Run alba's benchmark suite against this working tree"
  task :alba do
    dir = File.expand_path('../performance/alba', __FILE__)
    gemfile = File.join(dir, 'Gemfile')

    script = ENV.fetch('SCRIPT', 'collection.rb')

    # This task runs under `bundle exec rake`, so the repo's own bundle is
    # already in the environment. Without unbundling, its BUNDLE_GEMFILE and
    # RUBYOPT leak into the child and it resolves against the wrong Gemfile.
    Bundler.with_unbundled_env do
      ENV['BUNDLE_GEMFILE'] = gemfile
      Dir.chdir(dir) do
        sh('bundle', 'install') unless File.exist?("#{gemfile}.lock")
        sh('bundle', 'exec', 'ruby', script)
      end
    end
  end
end

task test: "test:all"
