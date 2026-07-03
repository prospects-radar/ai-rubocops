# frozen_string_literal: true

module RuboCop
  module Cop
    module Mcp
      # Enforces that the automation / MCP API controllers
      # (`app/controllers/api/v1/automation/**`) are thin routing layers that
      # delegate ALL business logic to `Automation::*` services (DEC-013).
      #
      # These controllers back both the `make_app/rpcs/*` MCP tools and the
      # n8n / Make / Zapier automation APIs. They must contain no inline data
      # access: no ActiveRecord query/persistence calls and no direct model
      # constant usage. Reads delegate via `render_service_collection`, writes
      # via `respond_with_service`. Keeping the logic in services keeps it DRY
      # and reusable across the MCP, automation, and UI fronts.
      #
      # `base_controller.rb` is excluded — it legitimately performs auth and
      # tenant-resolution lookups, which are infrastructure, not business logic.
      #
      # @example Bad — inline query in a controller action
      #   def index
      #     prospects = current_account.prospects.joins(:prospect_company).limit(200)
      #     render_success(prospects)
      #   end
      #
      # @example Bad — direct model constant
      #   def companies
      #     render_success(Company.where("name ILIKE ?", "%#{params[:name]}%"))
      #   end
      #
      # @example Good — delegate to a service
      #   def index
      #     render_service_collection(
      #       ::Automation::ListProspectsService.new(params: { action: :index }).call,
      #       :prospects
      #     )
      #   end
      #
      class AutomationControllerDelegation < Base
        MSG = "Automation/MCP API controllers must delegate to `Automation::*` services. " \
              "Move `%<name>s` into a service (DEC-013); keep controllers thin and DRY."

        # Unambiguous ActiveRecord query + persistence methods. Generic
        # Enumerable-ish names (find/first/count/select/map/new) are deliberately
        # omitted to avoid false positives — `Service.new(...).call` delegation
        # and array operations must stay legal.
        QUERY_METHODS = %i[
          where joins left_joins includes preload eager_load references
          order reorder limit offset group having distinct pluck
          find_by find_by! find_each find_in_batches exists? all none unscoped
          save save! create create! create_or_find_by first_or_create first_or_create!
          update update! update_all update_column update_columns
          destroy destroy! destroy_all delete delete_all increment! decrement!
        ].freeze

        AR_MODELS = %w[
          Prospect Company Product Task Stakeholder CompanyTimelineEvent
          IdealCustomerProfile ProspectOverallScore BuyingReadinessSnapshot
          AccountUser Account User Subscription Plan M49Region
          AutomationEvent AutomationSubscription AutomationApiKey
        ].freeze

        def on_send(node)
          return unless enforced_file?

          if QUERY_METHODS.include?(node.method_name)
            add_offense(node.loc.selector, message: format(MSG, name: node.method_name))
            return
          end

          receiver = node.receiver
          return unless receiver&.const_type?
          return unless AR_MODELS.include?(receiver.short_name.to_s)

          add_offense(receiver, message: format(MSG, name: receiver.short_name))
        end

        private

        def enforced_file?
          path = processed_source.path.to_s
          path.include?("app/controllers/api/v1/automation/") &&
            path.end_with?("_controller.rb") &&
            !path.end_with?("base_controller.rb")
        end
      end
    end
  end
end
