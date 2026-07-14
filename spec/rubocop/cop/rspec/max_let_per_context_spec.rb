# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::MaxLetPerContext, :config do
  subject(:cop) { described_class.new(config) }

  # Max defaults to 5 in the cop, so a bare config exercises the default.
  let(:config) { RuboCop::Config.new }
  let(:path) { "spec/models/thing_spec.rb" }

  it "registers an offense for a context with more than Max lets" do
    expect_offense(<<~RUBY, path)
      RSpec.describe Thing do
            ^^^^^^^^ RSpec/MaxLetPerContext: Context declares 6 `let`/`let!` (max 5). Aim for 1-3; push extras into the narrower contexts that use them.
        let(:a) { 1 }
        let(:b) { 2 }
        let(:c) { 3 }
        let(:d) { 4 }
        let(:e) { 5 }
        let(:f) { 6 }
      end
    RUBY
  end

  it "counts let! toward the total" do
    expect_offense(<<~RUBY, path)
      describe Thing do
      ^^^^^^^^ RSpec/MaxLetPerContext: Context declares 6 `let`/`let!` (max 5). Aim for 1-3; push extras into the narrower contexts that use them.
        let(:a) { 1 }
        let(:b) { 2 }
        let(:c) { 3 }
        let(:d) { 4 }
        let(:e) { 5 }
        let!(:f) { 6 }
      end
    RUBY
  end

  it "does not count lets in nested contexts against the parent" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        let(:a) { 1 }
        let(:b) { 2 }

        context "nested" do
          let(:c) { 3 }
          let(:d) { 4 }
          let(:e) { 5 }
          let(:f) { 6 }
        end
      end
    RUBY
  end

  it "accepts a context at exactly Max" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        let(:a) { 1 }
        let(:b) { 2 }
        let(:c) { 3 }
        let(:d) { 4 }
        let(:e) { 5 }
      end
    RUBY
  end

  it "ignores non-spec files" do
    expect_no_offenses(<<~RUBY, "app/models/thing.rb")
      describe Thing do
        let(:a) { 1 }
        let(:b) { 2 }
        let(:c) { 3 }
        let(:d) { 4 }
        let(:e) { 5 }
        let(:f) { 6 }
      end
    RUBY
  end
end
