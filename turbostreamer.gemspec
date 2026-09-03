require File.expand_path("../lib/turbostreamer/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "turbostreamer"
  spec.version       = TurboStreamer::VERSION
  spec.licenses      = ['MIT']
  spec.authors       = ["Jon Bracy"]
  spec.email         = ["jonbracy@gmail.com"]
  spec.homepage      = "https://github.com/malomalo/turbostreamer"
  spec.summary       = 'Stream JSON via a Builder-style DSL'
  spec.description   = <<~DESC
    TurboStreamer is a JBuilder-like DSL for building
    JSON that streams directly to a string or IO
  DESC

  spec.metadata = {
    'source_code_uri'       => spec.homepage,
    'bug_tracker_uri'       => "#{spec.homepage}/issues",
    'changelog_uri'         => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'rubygems_mfa_required' => 'true'
  }

  spec.extra_rdoc_files = %w(README.md)
  spec.rdoc_options.concat ['--main', 'README.md']

  spec.files         = `git ls-files -z -- README.md LICENSE CHANGELOG.md lib`.split("\x0")
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 3.3.0'

  spec.add_runtime_dependency 'activesupport', '>= 8.0.0'

  spec.add_development_dependency "rake"
  spec.add_development_dependency "wankel"
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency "oj"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "actionview"
  spec.add_development_dependency "actionpack"
  spec.add_development_dependency "railties"
  # The gems used only by `rake performance` (analyzer, jbuilder, rabl,
  # multi_json) live in the Gemfile's optional :performance group so CI doesn't
  # install them for every matrix cell.
end
