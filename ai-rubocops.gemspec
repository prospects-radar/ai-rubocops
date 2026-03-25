# frozen_string_literal: true

require_relative "lib/ai-rubocops/version"

Gem::Specification.new do |spec|
  spec.name = "ai-rubocops"
  spec.version = AiRubocops::VERSION
  spec.authors = ["Enterprise Modules"]
  spec.email = ["info@enterprisemodules.com"]

  spec.summary = "Custom RuboCop cops for ProspectsRadar"
  spec.description = "Project-specific RuboCop cops enforcing DesignSystem, service layer, " \
                     "RAAF agent, testing, and tenant safety conventions for the ProspectsRadar application."
  spec.homepage = "https://github.com/enterprisemodules/ai-rubocops"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,docs}/**/*", "README.md", "CHANGELOG.md", "LICENSE", "ai-rubocops.gemspec"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rubocop", ">= 1.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
end
