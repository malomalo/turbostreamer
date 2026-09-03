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
  %w(rolftimmermans dirk).each do |suite|
    base = File.expand_path("../performance/#{suite}", __FILE__)
    paths = files.map { |i| File.join(base, i) }

    { 'report-cached.png' => 'true', 'report-uncached.png' => 'false' }.each do |output, caching|
      ENV['PERFORM_CACHING'] = caching
      analyzer = Analyzer.new(*paths, lib: File.join(base, 'lib.rb'))
      analyzer.plot(File.join(base, output))
    end
  end
ensure
  ENV.delete('PERFORM_CACHING')
end

task test: "test:all"
