# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::UnregisteredEvaluator, :config do
  # The fixture manifests list Performance::Latency and nothing else.
  let(:fixture_root) { File.expand_path("../../../fixtures/raaf_registry", __dir__) }
  let(:cop_config) do
    {
      # The shared `:config` context merges config/default.yml, whose Include
      # scopes this cop to RAAF's tree. Fixtures live elsewhere.
      "Include" => ["**/*.rb"],
      "EvaluatorsRoot" => "raaf_registry",
      "AllowedNames" => %w[BaseEvaluator Base],
      "Manifests" => ["all_evaluators.rb", "evaluator_registry.rb"]
    }
  end

  it "registers an offense for an evaluator missing from both manifests" do
    expect_offense(<<~RUBY, "#{fixture_root}/performance/cost_efficiency.rb")
      class CostEfficiency
            ^^^^^^^^^^^^^^ `CostEfficiency` is missing from all_evaluators.rb and evaluator_registry.rb, so nothing can load or resolve it.
        evaluator_name :cost_efficiency
      end
    RUBY
  end

  it "accepts an evaluator both manifests list" do
    expect_no_offenses(<<~RUBY, "#{fixture_root}/performance/latency.rb")
      class Latency
        evaluator_name :latency
      end
    RUBY
  end

  it "ignores classes that are not evaluators" do
    expect_no_offenses(<<~RUBY, "#{fixture_root}/performance/helper.rb")
      class Helper
      end
    RUBY
  end
end
