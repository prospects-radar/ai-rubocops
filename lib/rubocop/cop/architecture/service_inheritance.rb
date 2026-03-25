# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Enforces that all service classes inherit from BaseService.
      #
      # This ensures compliance with the mandatory Service-Controller Architecture (DEC-013),
      # where all business logic belongs in services that inherit from BaseService.
      #
      # @example
      #   # bad
      #   class MyService
      #     def call
      #       # business logic
      #     end
      #   end
      #
      #   # good
      #   class MyService < BaseService
      #     private
      #
      #     def index
      #       success_result(resources: Resource.all)
      #     end
      #   end
      #
      class ServiceInheritance < Base
        extend AutoCorrector

        MSG = "Service classes must inherit from BaseService (DEC-013). " \
              "This provides access to success_result, error_result, and other DSL features."

        def on_class(node)
          return unless service_class?(node)
          return if excluded_service?(node)
          return if inherits_from_base_service?(node)

          add_offense(node.identifier, message: MSG) do |corrector|
            if node.parent_class.nil?
              # Class has no parent, add inheritance
              corrector.replace(node.loc.name, "#{node.identifier.source} < BaseService")
            else
              # Class has wrong parent, replace it
              corrector.replace(node.parent_class, "BaseService")
            end
          end
        end

        private

        def service_class?(node)
          class_name = node.identifier.source
          file_path = processed_source.file_path

          # Check if it's a service by name or path
          class_name.end_with?("Service") || file_path.include?("app/services/")
        end

        def excluded_service?(node)
          class_name = node.identifier.source
          cop_config.fetch("ExcludedServices", %w[
            ClassificationService
            PreviewDataService
            ValueDashboardPdfGenerator
          ]).include?(class_name)
        end

        def inherits_from_base_service?(node)
          parent = node.parent_class
          return false unless parent

          parent_name = parent.source
          # Allow various forms of BaseService reference
          %w[BaseService ::BaseService ApplicationService ::ApplicationService].include?(parent_name)
        end
      end
    end
  end
end
