# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::PromptNoPlaceholderFallback, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  def message(literal)
    "RAAF/PromptNoPlaceholderFallback: `|| #{literal}` invents a value the model cannot tell from data. " \
      "Leave the field out, or say in a sentence that it is not known."
  end

  it "flags the BroadQueryFormulator fallbacks (#1679)", :aggregate_failures do
    expect_offense(<<~RUBY)
      company[:domain] || company["domain"] || "unknown.com"
                                               ^^^^^^^^^^^^^ #{message('"unknown.com"')}
      company[:industry] || "General"
                            ^^^^^^^^^ #{message('"General"')}
    RUBY
  end

  it "flags a fallback after presence" do
    expect_offense(<<~RUBY)
      name.presence || "Unknown Company"
                       ^^^^^^^^^^^^^^^^^ #{message('"Unknown Company"')}
    RUBY
  end

  it "accepts a sentence that says the fact is missing" do
    expect_no_offenses(<<~RUBY)
      company[:domain] || "No website is known."
      context[:notes] || "Nothing was recorded:"
    RUBY
  end

  it "accepts an empty string and non-string fallbacks" do
    expect_no_offenses(<<~RUBY)
      company[:name] || ""
      context[:lookback_days] || 730
      context[:mode] || :standard
      context[:items] || []
    RUBY
  end
end
