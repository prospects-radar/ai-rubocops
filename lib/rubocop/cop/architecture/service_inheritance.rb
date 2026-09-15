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

        # Paths where a class named *Service is a subject, not a service.
        # `Views::GlassMorph::Pages::TermsOfService` is a page about a service;
        # the autocorrector below rewrote its parent to BaseService, which left
        # Rails no `render_in` and the page served an empty 200 for as long as
        # nobody looked past the status code.
        NON_SERVICE_PATHS = %w[
          app/views/
          app/components/
          app/layouts/
        ].freeze

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

          return false if class_name.end_with?("Error")
          return false if NON_SERVICE_PATHS.any? { |path| file_path.include?(path) }

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
          # Allow BaseService and known intermediate base classes that inherit from it
          %w[BaseService ::BaseService ApplicationService ::ApplicationService BaseAdapter].include?(parent_name)
        end
      end
    end
  end
end
