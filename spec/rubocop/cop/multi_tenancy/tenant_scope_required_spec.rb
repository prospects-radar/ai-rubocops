# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::MultiTenancy::TenantScopeRequired, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in model directory" do
    let(:source_file_path) { "app/models/company.rb" }

    it "registers offense for model with belongs_to :account but no acts_as_tenant" do
      expect_offense(<<~RUBY, source_file_path)
        class Company < ApplicationRecord
              ^^^^^^^ MultiTenancy/TenantScopeRequired: Models with `belongs_to :account` must use `acts_as_tenant :account` to prevent cross-tenant data leakage.
          belongs_to :account
        end
      RUBY
    end

    it "does not register offense when acts_as_tenant is present" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Company < ApplicationRecord
          acts_as_tenant :account
          belongs_to :account
        end
      RUBY
    end

    it "does not register offense for excluded models" do
      expect_no_offenses(<<~RUBY, "app/models/account.rb")
        class Account < ApplicationRecord
          belongs_to :account
        end
      RUBY
    end

    it "does not register offense for models without belongs_to :account" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Tag < ApplicationRecord
          has_many :taggings
        end
      RUBY
    end
  end

  context "when in concerns directory" do
    let(:source_file_path) { "app/models/concerns/tenantable.rb" }

    it "does not check concern files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Tenantable < ApplicationRecord
          belongs_to :account
        end
      RUBY
    end
  end

  context "when not in model directory" do
    let(:source_file_path) { "app/services/my_service.rb" }

    it "does not check non-model files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class MyService < BaseService
          belongs_to :account
        end
      RUBY
    end
  end
end
