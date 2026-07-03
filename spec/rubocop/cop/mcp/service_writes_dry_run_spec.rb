# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Mcp::ServiceWritesDryRun, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:source_file_path) { "app/services/mcp/company_service.rb" }

  # ── Mutating by name prefix ───────────────────────────────────────────────

  context "when method name starts with update_" do
    it "registers offense with no dry_run param" do
      expect_offense(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def update(id:, changes:)
                ^^^^^^ Mcp/ServiceWritesDryRun: Mutating Mcp service method `update` must accept `dry_run:` or delegate to `update_with_dry_run`. AI clients need a preview mode before committing writes.
              call_service(::CompanyService, :show, id: id)
            end
          end
        end
      RUBY
    end

    it "does not register offense when dry_run: kwarg present" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def update(id:, changes:, dry_run: true)
              call_service(::CompanyService, :show, id: id)
            end
          end
        end
      RUBY
    end

    it "does not register offense when update_with_dry_run called" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def update(id:, changes:, dry_run: true)
              update_with_dry_run(::CompanyService, id: id, changes: changes,
                                  dry_run: dry_run, result_key: :company, id_key: :company_id)
            end
          end
        end
      RUBY
    end

    it "registers offense for create_ prefix with no dry_run" do
      expect_offense(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def create_note(prospect_id:, body:)
                ^^^^^^^^^^^ Mcp/ServiceWritesDryRun: Mutating Mcp service method `create_note` must accept `dry_run:` or delegate to `update_with_dry_run`. AI clients need a preview mode before committing writes.
            end
          end
        end
      RUBY
    end

    it "registers offense for destroy_ prefix with no dry_run" do
      expect_offense(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def destroy_tag(id:)
                ^^^^^^^^^^^ Mcp/ServiceWritesDryRun: Mutating Mcp service method `destroy_tag` must accept `dry_run:` or delegate to `update_with_dry_run`. AI clients need a preview mode before committing writes.
            end
          end
        end
      RUBY
    end
  end

  # ── Mutating by call_service action ──────────────────────────────────────

  context "when method calls call_service with mutating action" do
    it "registers offense for :update action without dry_run" do
      expect_offense(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def apply_changes(id:, data:)
                ^^^^^^^^^^^^^ Mcp/ServiceWritesDryRun: Mutating Mcp service method `apply_changes` must accept `dry_run:` or delegate to `update_with_dry_run`. AI clients need a preview mode before committing writes.
              call_service(::CompanyService, :update, id: id, data: data)
            end
          end
        end
      RUBY
    end

    it "does not register offense for :show action" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def find(id)
              call_service(::CompanyService, :show, id: id)
            end
          end
        end
      RUBY
    end

    it "does not register offense for :index action" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            def list
              call_service(::CompanyService, :index)
            end
          end
        end
      RUBY
    end
  end

  # ── Private methods exempt ────────────────────────────────────────────────

  context "when method is private" do
    it "does not check private methods after bare private keyword" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            private

            def update_internal(id:)
              call_service(::CompanyService, :update, id: id, data: {})
            end
          end
        end
      RUBY
    end

    it "does not check inline private def" do
      expect_no_offenses(<<~RUBY, source_file_path)
        module Mcp
          class CompanyService < Base
            private def update_internal(id:)
              call_service(::CompanyService, :update, id: id, data: {})
            end
          end
        end
      RUBY
    end
  end

  # ── Non-MCP / excluded files ──────────────────────────────────────────────

  context "when not in app/services/mcp/" do
    it "does not check regular service files" do
      expect_no_offenses(<<~RUBY, "app/services/company_service.rb")
        class CompanyService < BaseService
          def update
            # ...
          end
        end
      RUBY
    end

    it "does not check base.rb" do
      expect_no_offenses(<<~RUBY, "app/services/mcp/base.rb")
        module Mcp
          class Base
            def update_with_dry_run(*)
            end
          end
        end
      RUBY
    end
  end
end
