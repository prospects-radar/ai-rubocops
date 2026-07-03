# frozen_string_literal: true

module RuboCop
  module Cop
    module Mcp
      # Enforces that mutating public methods in Mcp services support dry_run preview.
      #
      # A method is considered mutating when any of the following hold:
      # - Its name begins with `update_`, `create_`, or `destroy_`
      # - Its body calls `call_service` with a mutating action (:update, :create, :destroy)
      #
      # A mutating method complies when it either:
      # - Accepts a `dry_run:` keyword argument, OR
      # - Delegates to `update_with_dry_run`
      #
      # Private methods are not checked — they are internal helpers, not AI-facing interface.
      #
      # @example Bad — mutating method, no preview mode
      #   # app/services/mcp/company_service.rb
      #   def update(id:, changes:)
      #     call_service(::CompanyService, :update, id: id, data: changes)
      #   end
      #
      # @example Good — accepts dry_run param
      #   def update(id:, changes:, dry_run: true)
      #     call_service(::CompanyService, :update, id: id, data: changes) unless dry_run
      #   end
      #
      # @example Good — delegates to update_with_dry_run
      #   def update(id:, changes:, dry_run: true)
      #     update_with_dry_run(::CompanyService, id: id, changes: changes, dry_run: dry_run,
      #                         result_key: :company, id_key: :company_id)
      #   end
      #
      class ServiceWritesDryRun < Base
        MSG = "Mutating Mcp service method `%<method>s` must accept `dry_run:` or " \
              "delegate to `update_with_dry_run`. AI clients need a preview mode before " \
              "committing writes."

        MUTATING_ACTIONS  = %i[update create destroy].freeze
        MUTATING_NAMES    = %w[update create destroy].freeze
        MUTATING_PREFIXES = %w[update_ create_ destroy_].freeze

        def on_def(node)
          return unless mcp_service_file?
          return if private_method_context?(node)
          return unless mutating_method?(node)
          return if has_dry_run_param?(node)
          return if calls_update_with_dry_run?(node)

          add_offense(node.loc.name, message: format(MSG, method: node.method_name))
        end

        private

        def mcp_service_file?
          path = processed_source.path.to_s
          path.include?("app/services/mcp/") && !path.end_with?("/base.rb")
        end

        def private_method_context?(node)
          # Case: `private def method_name`
          parent = node.parent
          return true if parent&.send_type? && parent.method_name == :private

          # Case: def appears after a bare `private` in the class/module body
          return false unless parent

          siblings = parent.children
          method_index = siblings.index(node)
          return false unless method_index

          siblings[0...method_index].any? do |sibling|
            sibling.send_type? &&
              sibling.method_name == :private &&
              sibling.arguments.empty?
          end
        end

        def mutating_method?(node)
          name = node.method_name.to_s
          return true if MUTATING_NAMES.include?(name)
          return true if MUTATING_PREFIXES.any? { |prefix| name.start_with?(prefix) }

          calls_mutating_service_action?(node)
        end

        def calls_mutating_service_action?(node)
          node.each_descendant(:send).any? do |send_node|
            send_node.method_name == :call_service &&
              send_node.arguments[1]&.sym_type? &&
              MUTATING_ACTIONS.include?(send_node.arguments[1].value)
          end
        end

        def has_dry_run_param?(node)
          node.arguments.any? do |arg|
            (arg.kwarg_type? || arg.kwoptarg_type?) &&
              arg.children.first == :dry_run
          end
        end

        def calls_update_with_dry_run?(node)
          node.each_descendant(:send).any? do |send_node|
            send_node.method_name == :update_with_dry_run
          end
        end
      end
    end
  end
end
