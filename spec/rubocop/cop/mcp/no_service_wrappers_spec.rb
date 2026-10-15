# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Mcp::NoServiceWrappers, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in app/services/mcp/" do
    it "registers an offense for a new MCP service" do
      expect_offense(<<~RUBY, "app/services/mcp/product_service.rb")
        module Mcp
          class ProductService < Base
                ^^^^^^^^^^^^^^ Mcp/NoServiceWrappers: Do not add MCP-specific services. Call the app service the screens use (ProductService, CompanyService, ...) from the tool, and extend that service when it lacks an action or a permitted field.
          end
        end
      RUBY
    end

    it "leaves base.rb alone" do
      expect_no_offenses(<<~RUBY, "app/services/mcp/base.rb")
        module Mcp
          class Base
          end
        end
      RUBY
    end
  end

  context "when in an MCP tool" do
    let(:path) { "app/ai/tools/mcp/member/update_product.rb" }

    it "registers an offense for a call through an Mcp::*Service wrapper" do
      expect_offense(<<~RUBY, path)
        result = ::Mcp::ProductService.new(user: user, account: account).update(name: name)
                 ^^^^^^^^^^^^^^^^^^^^^ Mcp/NoServiceWrappers: MCP tools call app services directly (`call_service(::ProductService, :update, ...)`), not an `Mcp::*Service` wrapper.
      RUBY
    end

    it "accepts a call to an app service" do
      expect_no_offenses(<<~RUBY, path)
        result = call_service(::ProductService, :update, id: 1, data: {})
      RUBY
    end

    it "accepts other Mcp constants such as errors" do
      expect_no_offenses(<<~RUBY, path)
        raise McpErrors::RecordNotFound.new("x")
        ::Mcp::AuditEvent.record(token: token)
      RUBY
    end
  end

  it "ignores files outside the MCP folders" do
    expect_no_offenses(<<~RUBY, "app/services/product_service.rb")
      ::Mcp::ProductService.new
    RUBY
  end
end
