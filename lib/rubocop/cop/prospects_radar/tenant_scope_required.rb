# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Enforces that models with an account_id column use acts_as_tenant.
      #
      # Multi-tenant data leakage is the most dangerous class of bug in this app.
      # Any model that belongs to an account must declare acts_as_tenant to ensure
      # queries are automatically scoped.
      #
      # Configure excluded models via `ExcludedModels` in .rubocop.yml:
      #
      #   ProspectsRadar/TenantScopeRequired:
      #     ExcludedModels:
      #       - Account
      #       - User
      #       - AccountInvitation  # queried globally to bootstrap tenant
      #
      # @example
      #   # bad
      #   class Company < ApplicationRecord
      #     belongs_to :account
      #   end
      #
      #   # good
      #   class Company < ApplicationRecord
      #     acts_as_tenant :account
      #   end
      #
      class TenantScopeRequired < Base
        MSG = "Models with `belongs_to :account` must use `acts_as_tenant :account` " \
              "to prevent cross-tenant data leakage."

        def_node_search :has_acts_as_tenant?, <<~PATTERN
          (send nil? :acts_as_tenant (sym :account) ...)
        PATTERN

        def_node_search :has_belongs_to_account?, <<~PATTERN
          (send nil? :belongs_to (sym :account) ...)
        PATTERN

        def on_class(node)
          return unless in_model_directory?
          return if excluded_model?(node)
          return unless has_belongs_to_account?(node)
          return if has_acts_as_tenant?(node)

          add_offense(node.identifier, message: MSG)
        end

        private

        def in_model_directory?
          file_path = processed_source.file_path
          file_path.include?("app/models/") && !file_path.include?("/concerns/")
        end

        def excluded_model?(node)
          class_name = node.identifier.source
          excluded_models.include?(class_name)
        end

        # Account is always excluded — it IS the tenant model and cannot scope itself.
        ALWAYS_EXCLUDED = %w[Account].freeze

        def excluded_models
          ALWAYS_EXCLUDED + cop_config.fetch("ExcludedModels", [])
        end
      end
    end
  end
end
