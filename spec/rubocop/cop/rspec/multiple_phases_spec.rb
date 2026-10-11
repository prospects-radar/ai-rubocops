# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::MultiplePhases, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new("RSpec/MultiplePhases" => { "Max" => 2 }) }

  it "registers an offense for three act/assert phases" do
    expect_offense(<<~RUBY)
      it "walks the lifecycle" do
      ^^^^^^^^^^^^^^^^^^^^^^^^ This example has 3 act/assert phases (max 2). Split it so each phase is its own example.
        subscription.activate!
        expect(subscription).to be_active
        subscription.pause!
        expect(subscription).to be_paused
        subscription.cancel!
        expect(subscription).to be_canceled
      end
    RUBY
  end

  it "accepts two phases" do
    expect_no_offenses(<<~RUBY)
      it "toggles" do
        flag.toggle!
        expect(flag).to be_on
        flag.toggle!
        expect(flag).to be_off
      end
    RUBY
  end

  it "counts consecutive expectations as one phase" do
    expect_no_offenses(<<~RUBY)
      it "builds the record" do
        record = build_record
        expect(record.name).to eq("Foo")
        expect(record.status).to eq("active")
        expect(record.score).to be > 0
      end
    RUBY
  end

  it "counts a block expectation as an assert phase" do
    expect_offense(<<~RUBY)
      specify do
      ^^^^^^^ This example has 3 act/assert phases (max 2). Split it so each phase is its own example.
        expect { first.call }.to change(Task, :count).by(1)
        second.call
        is_expected.to be_valid
        third.call
        expect(third).to be_done
      end
    RUBY
  end

  it "ignores calls with a receiver named like an example" do
    expect_no_offenses(<<~RUBY)
      thing.it "x" do
        a; expect(a).to eq(1); b; expect(b).to eq(2); c; expect(c).to eq(3)
      end
    RUBY
  end

  context "with Max: 1" do
    let(:config) { RuboCop::Config.new("RSpec/MultiplePhases" => { "Max" => 1 }) }

    it "flags a second phase" do
      expect_offense(<<~RUBY)
        it "toggles" do
        ^^^^^^^^^^^^ This example has 2 act/assert phases (max 1). Split it so each phase is its own example.
          flag.toggle!
          expect(flag).to be_on
          flag.toggle!
          expect(flag).to be_off
        end
      RUBY
    end
  end
end
