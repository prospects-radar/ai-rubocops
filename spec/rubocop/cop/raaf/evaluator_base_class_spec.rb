# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::EvaluatorBaseClass, :config do
  let(:cop_config) do
    { "InterfaceModule" => "DSL::Evaluator", "BaseClass" => "RAAF::Eval::Evaluators::Base" }
  end

  it "registers an offense for a class that includes the interface module" do
    expect_offense(<<~RUBY)
      class Latency
            ^^^^^^^ Inherit from `RAAF::Eval::Evaluators::Base` instead of including `RAAF::Eval::DSL::Evaluator` directly; the base class already resolves thresholds and builds results.
        include RAAF::Eval::DSL::Evaluator
      end
    RUBY
  end

  it "accepts a class that inherits the base" do
    expect_no_offenses(<<~RUBY)
      class Faithfulness < BaseEvaluator
      end
    RUBY
  end

  it "accepts the base class itself including the module" do
    # BaseEvaluator has no superclass but is exempt via Exclude in config.yml;
    # a class that inherits anything at all is never reported.
    expect_no_offenses(<<~RUBY)
      class BaseEvaluator < Object
        include RAAF::Eval::DSL::Evaluator
      end
    RUBY
  end

  it "ignores classes that include something else" do
    expect_no_offenses(<<~RUBY)
      class Report
        include Comparable
      end
    RUBY
  end
end
