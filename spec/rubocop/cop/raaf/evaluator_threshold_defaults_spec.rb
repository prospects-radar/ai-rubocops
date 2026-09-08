# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::EvaluatorThresholdDefaults, :config do
  let(:message) do
    "Resolve thresholds with `resolve_thresholds(options)` " \
      "and class-level DEFAULT_*_THRESHOLD constants instead of defaulting inline."
  end

  it "registers an offense for an inline threshold default" do
    expect_offense(<<~RUBY, message: message)
      good_threshold = options[:good_threshold] || 0.8
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ %{message}
    RUBY
  end

  it "registers one offense for a chained fallback" do
    expect_offense(<<~RUBY, message: message)
      threshold_good = options[:threshold_good] || options[:good_threshold] || 0.85
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ %{message}
    RUBY
  end

  it "registers an offense for an integer default" do
    expect_offense(<<~RUBY, message: message)
      average = options[:threshold_average] || 1
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ %{message}
    RUBY
  end

  it "accepts resolving through the base class" do
    expect_no_offenses("good_threshold, average_threshold = resolve_thresholds(options)")
  end

  it "accepts a threshold read with no literal fallback" do
    expect_no_offenses("good_threshold = options[:good_threshold] || @default_good_threshold")
  end

  it "ignores fallbacks for other options" do
    expect_no_offenses("max_ms = options[:max_ms] || 2000")
  end
end
