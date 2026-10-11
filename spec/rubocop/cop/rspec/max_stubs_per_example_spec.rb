# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::MaxStubsPerExample, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new("RSpec/MaxStubsPerExample" => { "Max" => 3 }) }

  it "registers an offense for four stubs in one example" do
    expect_offense(<<~RUBY)
      it "syncs the order" do
      ^^^^^^^^^^^^^^^^^^^^ This example sets up 4 stubs or doubles (max 3). Test the collaborators for real, or move shared stubs into a context.
        allow(Gateway).to receive(:fetch).and_return(order)
        allow(Mapper).to receive(:call).and_return(payload)
        allow(Client).to receive(:post).and_return(response)
        allow(Notifier).to receive(:notify)

        described_class.call(order.id)

        expect(Client).to have_received(:post).with(payload)
      end
    RUBY
  end

  it "counts doubles, stub_const and stub_request" do
    expect_offense(<<~RUBY)
      it "fakes the world" do
      ^^^^^^^^^^^^^^^^^^^^ This example sets up 4 stubs or doubles (max 3). Test the collaborators for real, or move shared stubs into a context.
        client = instance_double(Client)
        stub_const("Limits::MAX", 1)
        stub_request(:get, "https://example.com")
        logger = spy
        expect(run(client, logger)).to be_ok
      end
    RUBY
  end

  it "accepts three stubs" do
    expect_no_offenses(<<~RUBY)
      it "syncs" do
        allow(A).to receive(:a)
        allow(B).to receive(:b)
        allow(C).to receive_messages(c: 1, d: 2)
        expect(run).to be_ok
      end
    RUBY
  end

  it "does not count have_received" do
    expect_no_offenses(<<~RUBY)
      it "checks the calls" do
        allow(A).to receive(:a)
        run
        expect(A).to have_received(:a)
        expect(B).to have_received(:b)
        expect(C).to have_received(:c)
        expect(D).to have_received(:d)
      end
    RUBY
  end

  it "does not count stubs in a before block" do
    expect_no_offenses(<<~RUBY)
      describe "x" do
        before do
          allow(A).to receive(:a)
          allow(B).to receive(:b)
          allow(C).to receive(:c)
          allow(D).to receive(:d)
        end

        it "runs" do
          expect(run).to be_ok
        end
      end
    RUBY
  end
end
