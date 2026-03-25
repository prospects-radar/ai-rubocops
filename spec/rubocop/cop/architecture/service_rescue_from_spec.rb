# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Architecture::ServiceRescueFrom, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in service file" do
    let(:source_file_path) { "app/services/company_service.rb" }

    it "registers offense for rescue block without error_result" do
      expect_offense(<<~RUBY, source_file_path)
        class CompanyService < BaseService
          def create
            resource.save!
          rescue ActiveRecord::RecordInvalid => e
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Architecture/ServiceRescueFrom: Prefer `rescue_from` DSL over inline rescue blocks in services. If inline rescue is necessary, ensure it returns error_result() and logs the error.
            { error: e.message }
          end
        end
      RUBY
    end

    it "does not register offense when rescue returns error_result" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyService < BaseService
          def create
            resource.save!
          rescue ActiveRecord::RecordInvalid => e
            error_result(e.message, error_type: :validation_failed)
          end
        end
      RUBY
    end

    it "does not register offense for private helper methods" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyService < BaseService
          private

          def fetch_external_data
            api_client.get("/data")
          rescue Faraday::Error => e
            nil
          end
        end
      RUBY
    end
  end

  context "when not in service file" do
    let(:source_file_path) { "app/models/company.rb" }

    it "does not check non-service files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Company < ApplicationRecord
          def save_safely
            save!
          rescue ActiveRecord::RecordInvalid
            false
          end
        end
      RUBY
    end
  end
end
