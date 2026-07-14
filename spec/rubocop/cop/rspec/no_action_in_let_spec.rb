# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::NoActionInLet, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:path) { "spec/services/thing_spec.rb" }

  it "registers an offense when a let runs the subject" do
    expect_offense(<<~RUBY, path)
      describe Thing do
        let(:result) { described_class.new(params).call }
        ^^^ RSpec/NoActionInLet: `let(:result)` performs an action (`call`). `let` is for values; move the action to a `before` block or inline it.
      end
    RUBY
  end

  it "registers an offense for a mail side effect" do
    expect_offense(<<~RUBY, path)
      describe Thing do
        let(:sent) { UserMailer.welcome(user).deliver_now }
        ^^^ RSpec/NoActionInLet: `let(:sent)` performs an action (`deliver_now`). `let` is for values; move the action to a `before` block or inline it.
      end
    RUBY
  end

  it "does not flag factory value definitions" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        let(:user) { create(:user) }
        let(:company) { build(:company) }
      end
    RUBY
  end

  it "does not flag let! (eager setup is idiomatic)" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        let!(:result) { described_class.new(params).call }
      end
    RUBY
  end

  it "does not flag an action merely defined inside a lambda value" do
    expect_no_offenses(<<~RUBY, path)
      describe Thing do
        let(:callback) { ->(record) { record.deliver_now } }
      end
    RUBY
  end

  it "ignores non-spec files" do
    expect_no_offenses(<<~RUBY, "app/services/thing.rb")
      describe Thing do
        let(:result) { described_class.new(params).call }
      end
    RUBY
  end
end
