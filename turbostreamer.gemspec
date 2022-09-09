require File.expand_path("../lib/turbostreamer/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "turbostreamer"
  spec.version       = TurboStreamer::VERSION
  spec.licenses      = ['MIT']
  spec.authors       = ["Jon Bracy"]
  spec.email         = ["jonbracy@gmail.com"]
  spec.homepage      = "https://github.com/malomalo/turbostreamer"
  spec.summary       = 'Stream JSON via a Builder-style DSL'
  # spec.description   = %q{}

  spec.extra_rdoc_files = %w(README.md)
  spec.rdoc_options.concat ['--main', 'README.md']

  spec.files         = `git ls-files -- README.md {lib,ext}/*`.split("\n")
  spec.test_files    = `git ls-files -- {test}/*`.split("\n")
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.5'

  spec.add_runtime_dependency 'activesupport', '>= 5.0.0'

  spec.add_development_dependency "rake"
  spec.add_development_dependency "wankel"
  spec.add_development_dependency "oj"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "actionview"
  spec.add_development_dependency "actionpack"
  spec.add_development_dependency 'analyzer'
  spec.add_development_dependency 'jbuilder'
  spec.add_development_dependency 'rabl'
  spec.add_development_dependency "appraisal", "~> 2.0"
  # For running benchmark
  spec.add_development_dependency 'multi_json'
  # spec.add_development_dependency 'sdoc',                '~> 0.4'
  # spec.add_development_dependency 'sdoc-templates-42floors', '~> 0.3'
end
