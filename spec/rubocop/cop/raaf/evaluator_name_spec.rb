# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::EvaluatorName, :config do
  let(:cop_config) do
    { "BaseClasses" => %w[BaseEvaluator Evaluators::Base], "AllowedNames" => %w[BaseEvaluator Base] }
  end

  it "registers an offense for a subclass with no evaluator_name" do
    expect_offense(<<~RUBY)
      class TaskCompletion < BaseEvaluator
            ^^^^^^^^^^^^^^ Declare `evaluator_name`; the registry cannot register this evaluator without it.
        DEFAULT_GOOD_THRESHOLD = 0.85
      end
    RUBY
  end

  it "registers an offense for an including class with no evaluator_name" do
    expect_offense(<<~RUBY)
      class Latency
            ^^^^^^^ Declare `evaluator_name`; the registry cannot register this evaluator without it.
        include RAAF::Eval::DSL::Evaluator
      end
    RUBY
  end

  it "accepts an evaluator that declares its name" do
    expect_no_offenses(<<~RUBY)
      class TaskCompletion < BaseEvaluator
        evaluator_name :task_completion
        evaluator_type :llm_judge
      end
    RUBY
  end

  it "accepts the base class" do
    expect_no_offenses(<<~RUBY)
      class BaseEvaluator
        include RAAF::Eval::DSL::Evaluator
      end
    RUBY
  end

  it "ignores classes that are not evaluators" do
    expect_no_offenses(<<~RUBY)
      class SpanAccessor
      end
    RUBY
  end
end
