# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::TestDataOrdering, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in spec file" do
    let(:source_file_path) { "spec/models/company_spec.rb" }

    it "registers offense for .last on AR query without ordering" do
      expect_offense(<<~RUBY, source_file_path)
        it "returns the latest" do
          expect(Company.all.last).to be_present
                             ^^^^ RSpec/TestDataOrdering: Avoid `.last` without explicit ordering in specs. [...]
        end
      RUBY
    end

    it "registers offense for .first on AR query without ordering" do
      expect_offense(<<~RUBY, source_file_path)
        it "returns the first" do
          expect(Company.where(active: true).first).to be_present
                                             ^^^^^ RSpec/TestDataOrdering: Avoid `.first` without explicit ordering in specs. [...]
        end
      RUBY
    end

    it "does not register offense with explicit order" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "returns the latest" do
          expect(Company.order(:created_at).last).to be_present
        end
      RUBY
    end

    it "does not register offense on array" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "returns the first element" do
          expect([1, 2, 3].first).to eq(1)
        end
      RUBY
    end

    it "does not register offense on local variable" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "returns the first element" do
          items = [1, 2, 3]
          expect(items.first).to eq(1)
        end
      RUBY
    end
  end

  context "when not in spec file" do
    let(:source_file_path) { "app/services/company_service.rb" }

    it "does not check non-spec files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        def latest_company
          Company.all.last
        end
      RUBY
    end
  end
end
