# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::EvaluatorLabelString, :config do
  it "registers an offense for a symbol label in a result hash" do
    expect_offense(<<~RUBY)
      { label: :good, score: 1.0 }
               ^^^^^ Use the string "good" for an evaluator label; EvaluationResult and validate_result! only recognise strings.
    RUBY

    expect_correction(<<~RUBY)
      { label: "good", score: 1.0 }
    RUBY
  end

  it "registers an offense for a label compared as a symbol" do
    # `calculate_label` returns a String, so this branch never fires.
    expect_offense(<<~RUBY)
      message = label == :good ? "fine" : "broken"
                         ^^^^^ Use the string "good" for an evaluator label; EvaluationResult and validate_result! only recognise strings.
    RUBY

    expect_correction(<<~RUBY)
      message = label == "good" ? "fine" : "broken"
    RUBY
  end

  it "registers an offense for a symbol returned from a label helper" do
    expect_offense(<<~RUBY)
      def calculate_label_from_discrete_thresholds(value, good:)
        return :good if value <= good
               ^^^^^ Use the string "good" for an evaluator label; EvaluationResult and validate_result! only recognise strings.

        :bad
        ^^^^ Use the string "bad" for an evaluator label; EvaluationResult and validate_result! only recognise strings.
      end
    RUBY
  end

  it "registers an offense for a symbol in a case branch" do
    expect_offense(<<~RUBY)
      score = case label
              when :good then 1.0
                   ^^^^^ Use the string "good" for an evaluator label; EvaluationResult and validate_result! only recognise strings.
              else 0.0
              end
    RUBY
  end

  it "accepts string labels" do
    expect_no_offenses('{ label: "good", score: 1.0 }')
  end

  it "accepts the words as hash keys" do
    expect_no_offenses("{ good: 0.8, average: 0.6, bad: 0.0 }")
  end

  it "accepts the words as matcher arguments" do
    # These are the keys `build_result` writes into its thresholds hash.
    expect_no_offenses("expect(result[:details][:thresholds]).to include(:good, :average, :used)")
  end

  it "accepts the words in a symbol array" do
    expect_no_offenses("expect(%i[good average]).to include(result[:label].to_sym)")
  end

  it "accepts the words as hash lookups" do
    # `build_result` writes `thresholds: { good:, average: }`; reading one back
    # is not a label.
    expect_no_offenses("expect(result[:details][:thresholds][:good]).to eq(0.8)")
  end

  it "ignores unrelated symbols" do
    expect_no_offenses("{ label: :excellent }")
  end
end
