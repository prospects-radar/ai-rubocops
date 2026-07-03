# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Mcp::AutomationControllerDelegation, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:controller_path) { "app/controllers/api/v1/automation/prospects_controller.rb" }

  context "with inline ActiveRecord query in an action" do
    it "registers an offense for the query method" do
      expect_offense(<<~RUBY, controller_path)
        class ProspectsController < BaseController
          def index
            scope.where(active: true)
                  ^^^^^ Mcp/AutomationControllerDelegation: Automation/MCP API controllers must delegate to `Automation::*` services. Move `where` into a service (DEC-013); keep controllers thin and DRY.
          end
        end
      RUBY
    end
  end

  context "with a direct model constant and a non-query method" do
    it "registers an offense for the model constant" do
      expect_offense(<<~RUBY, controller_path)
        class SearchesController < BaseController
          def companies
            Company.find(1)
            ^^^^^^^ Mcp/AutomationControllerDelegation: Automation/MCP API controllers must delegate to `Automation::*` services. Move `Company` into a service (DEC-013); keep controllers thin and DRY.
          end
        end
      RUBY
    end
  end

  context "when delegating to a service" do
    it "does not register an offense for Service.new(...).call" do
      expect_no_offenses(<<~RUBY, controller_path)
        class ProspectsController < BaseController
          def index
            render_service_collection(
              ::Automation::ListProspectsService.new(params: { action: :index }).call,
              :prospects
            )
          end
        end
      RUBY
    end

    it "allows strong-parameter permitting" do
      expect_no_offenses(<<~RUBY, controller_path)
        class SubscriptionsController < BaseController
          private

          def subscription_params
            params.require(:subscription).permit(:platform, :event_type, :target_url).to_h
          end
        end
      RUBY
    end
  end

  context "in base_controller.rb (excluded)" do
    let(:controller_path) { "app/controllers/api/v1/automation/base_controller.rb" }

    it "does not register an offense for auth/tenant lookups" do
      expect_no_offenses(<<~RUBY, controller_path)
        class BaseController < ActionController::Base
          def set_tenant_from_token
            user = User.find_by(id: doorkeeper_token.resource_owner_id)
          end
        end
      RUBY
    end
  end

  context "outside the automation controller path" do
    let(:controller_path) { "app/controllers/prospects_controller.rb" }

    it "does not register an offense" do
      expect_no_offenses(<<~RUBY, controller_path)
        class ProspectsController < ApplicationController
          def index
            @prospects = Prospect.all
          end
        end
      RUBY
    end
  end
end
