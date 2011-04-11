require File.expand_path("../lib/sandboxed/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "sandboxed"
  s.version = Sandboxed::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Michael Klaus"]
  s.email = ["Michael.Klaus@gmx.net"]
  s.homepage = "http://github.com/QaDeS/sandboxed"
  s.summary = "A ruby execution sandbox"
  s.description = "Execute code blocks in a $SAFE environment."

  s.required_rubygems_version = ">= 1.3.6"

  s.rubyforge_project = "sandboxed"  # as if...

  # If you have other dependencies, add them here
  s.add_development_dependency "rspec"

  s.files = Dir["{lib,spec}/**/*.rb", "LICENSE", "Gemfile"]
  s.require_path = 'lib'
end
