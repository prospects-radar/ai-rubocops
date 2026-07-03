# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Mcp::AdapterBase, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  # ── MCP Services ──────────────────────────────────────────────────────────

  context "when in app/services/mcp/" do
    let(:source_file_path) { "app/services/mcp/company_service.rb" }

    it "registers offense for service with no parent class" do
      expect_offense(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService
                ^^^^^^^^^^^^^^ Mcp/AdapterBase: Mcp service classes must inherit from `Base` (`Mcp::Base`). Provides `call_service`, `fetch_one`, `fetch_many`, and `update_with_dry_run` without duplicating boilerplate.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        module Mcp
          class CompanyService < Base
          end
        end
      RUBY
    end

    it "registers offense for service inheriting BaseService directly" do
      expect_offense(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < BaseService
                ^^^^^^^^^^^^^^ Mcp/AdapterBase: Mcp service classes must inherit from `Base` (`Mcp::Base`). Provides `call_service`, `fetch_one`, `fetch_many`, and `update_with_dry_run` without duplicating boilerplate.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        module Mcp
          class CompanyService < Base
          end
        end
      RUBY
    end

    it "does not register offense for service inheriting Base" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
          end
        end
      RUBY
    end

    it "does not register offense for service inheriting Mcp::Base" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Mcp::Base
          end
        end
      RUBY
    end

    it "does not check base.rb itself" do
      expect_no_offenses(<<~RUBY, "app/services/mcp/base.rb")
        module Mcp
          class Base
          end
        end
      RUBY
    end
  end

  # ── MCP Tools ─────────────────────────────────────────────────────────────

  context "when in app/ai/tools/mcp/" do
    let(:source_file_path) { "app/ai/tools/mcp/member/get_company.rb" }

    it "registers offense for tool with no parent class" do
      expect_offense(<<~RUBY, source_file_path)
        class GetCompany
              ^^^^^^^^^^ Mcp/AdapterBase: MCP tool classes must inherit from `Ai::Tools::Mcp::Base`. Provides `authorize_scope!`, `with_tenant`, `success`, `not_found`, and other tool DSL helpers.
        end
      RUBY

      expect_correction(<<~RUBY)
        class GetCompany < Ai::Tools::Mcp::Base
        end
      RUBY
    end

    it "registers offense for tool inheriting wrong parent" do
      expect_offense(<<~RUBY, source_file_path)
        class GetCompany < ApplicationRecord
              ^^^^^^^^^^ Mcp/AdapterBase: MCP tool classes must inherit from `Ai::Tools::Mcp::Base`. Provides `authorize_scope!`, `with_tenant`, `success`, `not_found`, and other tool DSL helpers.
        end
      RUBY

      expect_correction(<<~RUBY)
        class GetCompany < Ai::Tools::Mcp::Base
        end
      RUBY
    end

    it "does not register offense for tool inheriting Ai::Tools::Mcp::Base" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class GetCompany < Ai::Tools::Mcp::Base
        end
      RUBY
    end

    it "does not check base.rb itself" do
      expect_no_offenses(<<~RUBY, "app/ai/tools/mcp/base.rb")
        class Base
        end
      RUBY
    end
  end

  # ── Non-MCP files ─────────────────────────────────────────────────────────

  context "when not in an MCP directory" do
    it "does not check app/services/ files" do
      expect_no_offenses(<<~RUBY, "app/services/company_service.rb")
        class CompanyService
        end
      RUBY
    end

    it "does not check app/ai/agents/ files" do
      expect_no_offenses(<<~RUBY, "app/ai/agents/prospect_agent.rb")
        class ProspectAgent
        end
      RUBY
    end
  end
end
