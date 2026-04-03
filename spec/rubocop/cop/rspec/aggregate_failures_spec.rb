# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::AggregateFailures, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in spec file" do
    let(:source_file_path) { "spec/models/company_spec.rb" }

    it "registers offense for 3+ expectations without aggregate_failures" do
      expect_offense(<<~RUBY, source_file_path)
        it "validates the record" do
        ^^^^^^^^^^^^^^^^^^^^^^^^^ RSpec/AggregateFailures: Use `:aggregate_failures` when an `it` block has 3 expectations. This reports all failures at once instead of stopping at the first.
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
          expect(record.score).to be > 0
        end
      RUBY
    end

    it "autocorrects by adding :aggregate_failures after description" do
      expect_offense(<<~RUBY, source_file_path)
        it "validates the record" do
        ^^^^^^^^^^^^^^^^^^^^^^^^^ RSpec/AggregateFailures: Use `:aggregate_failures` when an `it` block has 3 expectations. This reports all failures at once instead of stopping at the first.
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
          expect(record.score).to be > 0
        end
      RUBY

      expect_correction(<<~RUBY)
        it "validates the record", :aggregate_failures do
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
          expect(record.score).to be > 0
        end
      RUBY
    end

    it "autocorrects when it block already has other metadata tags" do
      expect_offense(<<~RUBY, source_file_path)
        it "validates the record", :focus do
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ RSpec/AggregateFailures: Use `:aggregate_failures` when an `it` block has 3 expectations. This reports all failures at once instead of stopping at the first.
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
          expect(record.score).to be > 0
        end
      RUBY

      expect_correction(<<~RUBY)
        it "validates the record", :focus, :aggregate_failures do
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
          expect(record.score).to be > 0
        end
      RUBY
    end

    it "does not register offense with aggregate_failures tag" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "validates the record", :aggregate_failures do
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
          expect(record.score).to be > 0
        end
      RUBY
    end

    it "does not register offense with aggregate_failures block" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "validates the record" do
          aggregate_failures do
            expect(record.name).to eq("Foo")
            expect(record.status).to eq("active")
            expect(record.score).to be > 0
          end
        end
      RUBY
    end

    it "does not register offense for fewer than 3 expectations" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "validates the record" do
          expect(record.name).to eq("Foo")
          expect(record.status).to eq("active")
        end
      RUBY
    end
  end

  context "when not in spec file" do
    let(:source_file_path) { "app/models/company.rb" }

    it "does not check non-spec files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "something" do
          expect(1).to eq(1)
          expect(2).to eq(2)
          expect(3).to eq(3)
        end
      RUBY
    end
  end
end
