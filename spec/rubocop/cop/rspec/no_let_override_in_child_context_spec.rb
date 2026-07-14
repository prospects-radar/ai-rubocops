# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::NoLetOverrideInChildContext, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:path) { "spec/models/thing_spec.rb" }

  it "registers an offense when a child context overrides a parent let" do
    expect_offense(<<~RUBY, path)
      describe Thing do
        let(:user) { create(:user, admin: false) }

        context "as admin" do
          let(:user) { create(:user, admin: true) }
          ^^^ RSpec/NoLetOverrideInChildContext: `let(:user)` overrides a `let` from an enclosing context. Declare it in each child context instead of overriding the parent.
        end
      end
    RUBY
  end

  it "registers an offense across deeper nesting" do
    expect_offense(<<~RUBY, path)
      describe Thing do
        let(:params) { {} }

        context "outer" do
          context "inner" do
            let(:params) { { a: 1 } }
            ^^^ RSpec/NoLetOverrideInChildContext: `let(:params)` overrides a `let` from an enclosing context. Declare it in each child context instead of overriding the parent.
          end
        end
      end
    RUBY
  end

  it "does not flag sibling contexts each declaring their own let" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        context "as member" do
          let(:user) { create(:user, admin: false) }
        end

        context "as admin" do
          let(:user) { create(:user, admin: true) }
        end
      end
    RUBY
  end

  it "does not flag a single declaration" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        let(:user) { create(:user) }

        context "somewhere" do
          it { expect(user).to be_present }
        end
      end
    RUBY
  end

  it "ignores non-spec files" do
    expect_no_offenses(<<~RUBY, "app/models/thing.rb")
      describe Thing do
        let(:user) { 1 }

        context "x" do
          let(:user) { 2 }
        end
      end
    RUBY
  end
end
