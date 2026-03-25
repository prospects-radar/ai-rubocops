# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Ensures service specs set up tenant context
      #
      # @example
      #   # bad
      #   RSpec.describe CompanyService do
      #     it "creates company" do
      #       service.call
      #     end
      #   end
      #
      #   # good
      #   RSpec.describe CompanyService do
      #     before do
      #       ActsAsTenant.current_tenant = account
      #     end
      #
      #     it "creates company" do
      #       service.call
      #     end
      #   end
      #
      class ServiceRequiresTenantSetup < Base
        MSG = "Service specs should set up tenant context with `ActsAsTenant.current_tenant = account`"

        def_node_matcher :service_spec?, <<~PATTERN
          (block
            (send ... :describe
              (const nil? $_service_name)
              ...
            )
            ...
            ...
          )
        PATTERN

        def_node_search :has_tenant_setup?, <<~PATTERN
          (send (const nil? :ActsAsTenant) :current_tenant= ...)
        PATTERN

        def_node_search :has_shared_context?, <<~PATTERN
          (send nil? :include_context (str "service context"))
        PATTERN

        def on_block(node)
          service_spec?(node) do |service_name|
            return unless service_name.to_s.end_with?("Service")
            return if excluded_services.include?(service_name.to_s)
            return if has_tenant_setup?(node)
            return if has_shared_context?(node)

            add_offense(node)
          end
        end

        private

        def excluded_services
          cop_config.fetch("ExcludedServices", %w[BaseService])
        end
      end
    end
  end
end
