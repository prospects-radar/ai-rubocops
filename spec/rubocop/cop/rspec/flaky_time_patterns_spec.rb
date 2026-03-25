# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::FlakyTimePatterns, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in spec file" do
    let(:source_file_path) { "spec/models/record_spec.rb" }

    it "registers offense for Time.now" do
      expect_offense(<<~RUBY, source_file_path)
        it "checks expiration" do
          record = create(:record, expires_at: Time.now + 1.hour)
                                               ^^^^^^^^ RSpec/FlakyTimePatterns: Use `Time.current` with `freeze_time` or `travel_to` instead of `Time.now` in specs. [...]
        end
      RUBY
    end

    it "registers offense for Date.today" do
      expect_offense(<<~RUBY, source_file_path)
        it "checks creation date" do
          expect(record.created_at.to_date).to eq(Date.today)
                                                  ^^^^^^^^^^ RSpec/FlakyTimePatterns: Use a fixed date with `travel_to` instead of `Date.today` in specs. [...]
        end
      RUBY
    end

    it "does not register offense for Time.now inside freeze_time" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "checks expiration" do
          freeze_time do
            record = create(:record, expires_at: Time.now + 1.hour)
          end
        end
      RUBY
    end

    it "does not register offense for Date.today inside travel_to" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "checks creation date" do
          travel_to(Date.new(2024, 1, 1)) do
            expect(record.created_at.to_date).to eq(Date.today)
          end
        end
      RUBY
    end

    it "does not register offense for Time.current" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it "checks expiration" do
          record = create(:record, expires_at: Time.current + 1.hour)
        end
      RUBY
    end
  end

  context "when not in spec file" do
    let(:source_file_path) { "app/models/record.rb" }

    it "does not check non-spec files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        def expired?
          expires_at < Time.now
        end
      RUBY
    end
  end
end
