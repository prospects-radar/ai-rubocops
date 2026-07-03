# frozen_string_literal: true

module RuboCop
  module Cop
    module Mcp
      # Enforces that MCP tools AND Mcp::* services are thin adapters that
      # delegate to existing application services. Direct calls to ActiveRecord
      # model classes are not permitted — all data access must go through existing
      # app-level services (ProspectService, CompanyService, etc.).
      #
      # Applies to:
      #   - app/ai/tools/mcp/**/*.rb  (tools → delegate to Mcp::*Service)
      #   - app/services/mcp/**/*.rb  (Mcp services → delegate to existing app services)
      #
      # @example Bad — tool queries AR model directly
      #   # app/ai/tools/mcp/member/search_prospects.rb
      #   def call(...)
      #     Prospect.where(name: query).limit(10)
      #   end
      #
      # @example Bad — Mcp service queries AR model directly
      #   # app/services/mcp/prospect_service.rb
      #   def search(...)
      #     Prospect.includes(:prospect_company).where(...)
      #   end
      #
      # @example Good — tool delegates to Mcp service
      #   # app/ai/tools/mcp/member/search_prospects.rb
      #   def call(...)
      #     ::Mcp::ProspectService.new(...).search(query: query)
      #   end
      #
      # @example Good — Mcp service delegates to existing app service
      #   # app/services/mcp/prospect_service.rb
      #   def search(...)
      #     result = ProspectService.new(params: { action: :index, ... }).call
      #     serialize(result.prospects)
      #   end
      #
      class NoActiveRecordInTools < Base
        TOOL_MSG = "MCP tools must not call AR models directly. " \
                   "Delegate to an `Mcp::*Service` for `%<model>s` operations."

        SERVICE_MSG = "MCP services must not call AR models directly. " \
                      "Delegate to an existing app service for `%<model>s` operations."

        AR_MODELS = %w[
          Prospect
          Company
          Product
          Task
          Stakeholder
          CompanyTimelineEvent
          IdealCustomerProfile
          ProspectOverallScore
          BuyingReadinessSnapshot
          AccountUser
          Account
          User
          Subscription
          Plan
          ProspectDiscoveryRun
          AssistantProspect
          M49Region
          ScoringConfiguration
          ScoringCriterion
          ProspectIntelligenceProfile
        ].freeze

        def on_send(node)
          return unless enforced_file?

          receiver = node.receiver
          return unless receiver&.const_type?

          model_name = receiver.short_name.to_s
          return unless AR_MODELS.include?(model_name)

          msg = mcp_service_file? ? SERVICE_MSG : TOOL_MSG
          add_offense(receiver, message: format(msg, model: model_name))
        end

        private

        def enforced_file?
          mcp_tool_file? || mcp_service_file?
        end

        def mcp_tool_file?
          path = processed_source.path.to_s
          path.include?("app/ai/tools/mcp/") &&
            !path.end_with?("/base.rb") &&
            path.match?(%r{app/ai/tools/mcp/\w+/\w+\.rb})
        end

        def mcp_service_file?
          path = processed_source.path.to_s
          path.include?("app/services/mcp/") &&
            path.end_with?(".rb")
        end
      end
    end
  end
end
