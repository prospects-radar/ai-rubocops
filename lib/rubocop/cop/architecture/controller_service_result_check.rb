# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Enforces that controllers check service result success before rendering.
      #
      # When a controller calls a service and then renders or redirects, it must
      # check the result with .success? or use auto_service_call. Forgetting this
      # check silently swallows service failures.
      #
      # @example
      #   # bad - no result check
      #   def create
      #     result = CreateService.run(params)
      #     redirect_to resource_path
      #   end
      #
      #   # good - checks result
      #   def create
      #     result = CreateService.run(params)
      #     if result.success?
      #       redirect_to resource_path
      #     else
      #       render :new
      #     end
      #   end
      #
      #   # good - uses auto_service_call
      #   def create
      #     auto_service_call
      #   end
      #
      class ControllerServiceResultCheck < Base
        MSG = "Service result must be checked with `.success?` or `.failure?` before " \
              "render/redirect. Use `auto_service_call` or check the result explicitly."

        def on_def(node)
          return unless in_controller?
          return unless controller_action?(node)

          body = node.body
          return unless body

          # Collect all statements in the method body
          statements = body.begin_type? ? body.children : [ body ]

          check_unchecked_service_results(statements, node)
        end

        private

        def render_methods
          cop_config.fetch("RenderMethods", %w[render redirect_to turbo_redirect]).map(&:to_sym)
        end

        def in_controller?
          file_path = processed_source.file_path
          file_path.include?("app/controllers/") &&
            !file_path.include?("/concerns/") &&
            !file_path.end_with?("application_controller.rb")
        end

        def controller_action?(node)
          action_names = %i[
            index show new create edit update destroy
            approve reject publish unpublish archive restore
          ]

          action_names.include?(node.method_name)
        end

        def check_unchecked_service_results(statements, method_node)
          service_result_vars = []

          statements.each do |stmt|
            # Track service result assignments: result = SomeService.run(...)
            if service_result_assignment?(stmt)
              var_name = stmt.children[0]
              service_result_vars << var_name
            end

            # Check if render/redirect happens without checking the result
            if unchecked_render?(stmt, service_result_vars)
              add_offense(stmt, message: MSG)
            end
          end
        end

        def service_result_assignment?(node)
          return false unless node&.lvasgn_type?

          value = node.children[1]
          service_call?(value)
        end

        def service_call?(node)
          return false unless node&.send_type?

          method_name = node.method_name
          return true if %i[run call].include?(method_name) && service_receiver?(node.receiver)

          # Check for chained service calls: Service.new(...).run
          if %i[run call].include?(method_name) && node.receiver&.send_type?
            return service_receiver?(node.receiver.receiver) if node.receiver.method?(:new)
          end

          false
        end

        def service_receiver?(node)
          return false unless node

          if node.const_type?
            name = node.source
            return name.end_with?("Service")
          end

          false
        end

        def unchecked_render?(node, service_result_vars)
          return false if service_result_vars.empty?
          return false unless node&.send_type?
          return false unless render_methods.include?(node.method_name)

          # If render/redirect is inside an if/case checking .success?, it's fine
          # We only flag top-level render/redirect after a service call
          parent = node.parent
          return false if parent&.if_type? || parent&.case_type?

          true
        end
      end
    end
  end
end
