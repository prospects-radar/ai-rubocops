# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::MockImplementation, :config do
  let(:cop_config) { { "Pattern" => '\A(mock|simulate|fake|dummy)_' } }

  it "registers an offense for a mock_ method" do
    expect_offense(<<~RUBY)
      def mock_faithfulness_score(answer, context)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `mock_faithfulness_score` is placeholder scoring in library code; call a judge or raise NotImplementedError.
        0.6
      end
    RUBY
  end

  it "registers an offense for a simulate_ method" do
    expect_offense(<<~RUBY)
      def simulate_llm_judgment(value, criteria)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `simulate_llm_judgment` is placeholder scoring in library code; call a judge or raise NotImplementedError.
        0.7
      end
    RUBY
  end

  it "registers an offense for a singleton mock_ method" do
    expect_offense(<<~RUBY)
      def self.mock_score(value)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^ `mock_score` is placeholder scoring in library code; call a judge or raise NotImplementedError.
        0.5
      end
    RUBY
  end

  it "accepts a real judge call" do
    expect_no_offenses(<<~RUBY)
      def judge_faithfulness(answer, context)
        judge.score(build_faithfulness_prompt(answer, context))
      end
    RUBY
  end

  it "accepts an honest placeholder" do
    expect_no_offenses(<<~RUBY)
      def score(answer, context)
        raise NotImplementedError, "faithfulness needs a judge"
      end
    RUBY
  end
end
