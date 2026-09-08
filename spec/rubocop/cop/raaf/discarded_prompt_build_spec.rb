# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::DiscardedPromptBuild, :config do
  let(:cop_config) { { "Pattern" => '\Abuild_\w*prompt\z' } }

  it "registers an offense for a prompt built and dropped" do
    expect_offense(<<~RUBY)
      def llm_judge_faithfulness(answer:, context:)
        build_faithfulness_prompt(answer, context)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ The prompt built by `build_faithfulness_prompt` is discarded. Send it to a judge or delete the builder.
        mock_faithfulness_score(answer, context)
      end
    RUBY
  end

  it "accepts a prompt that is assigned" do
    expect_no_offenses(<<~RUBY)
      def llm_judge_faithfulness(answer:, context:)
        prompt = build_faithfulness_prompt(answer, context)
        judge.call(prompt)
      end
    RUBY
  end

  it "accepts a prompt that is passed straight to a judge" do
    expect_no_offenses(<<~RUBY)
      def llm_judge_faithfulness(answer:, context:)
        judge.call(build_faithfulness_prompt(answer, context))
      end
    RUBY
  end

  it "accepts a prompt returned as the method value" do
    expect_no_offenses(<<~RUBY)
      def prompt_for(answer)
        build_faithfulness_prompt(answer)
      end
    RUBY
  end

  it "ignores builders that are not prompts" do
    expect_no_offenses(<<~RUBY)
      def evaluate
        build_result(score, label)
        score
      end
    RUBY
  end
end
