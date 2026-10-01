# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Convention::PreferSymbolJsonAccess, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it "flags string access and corrects it to a symbol" do
    expect_offense(<<~RUBY)
      hash["status"]
          ^^^^^^^^^^ Convention/PreferSymbolJsonAccess: Use symbol access `[:status]` instead of string access `["status"]`. Normalize data with `.with_indifferent_access` at the boundary.
    RUBY

    expect_correction(<<~RUBY)
      hash[:status]
    RUBY
  end

  it "allows Rack environment variables read through request.env" do
    expect_no_offenses(<<~RUBY)
      request.env["HTTP_ACCEPT_LANGUAGE"]
    RUBY
  end

  it "allows HTTP header names read through request.headers" do
    expect_no_offenses(<<~RUBY)
      request.headers["Authorization"]
    RUBY
  end

  it "allows ENV access" do
    expect_no_offenses(<<~RUBY)
      ENV["OPENAI_API_KEY"]
    RUBY
  end

  it "allows Rake task lookup" do
    expect_no_offenses(<<~RUBY)
      Rake::Task["db:migrate"]
    RUBY
  end
end
