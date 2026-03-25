# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Enforces consistent service response format: success_result() and error_result().
      #
      # Services should return standardized hashes using BaseService helper methods,
      # not arbitrary data structures or raise exceptions for control flow.
      #
      # @example
      #   # bad
      #   def create
      #     { status: :ok, data: resource }  # Non-standard format
      #   end
      #
      #   # bad
      #   def update
      #     raise StandardError, "Failed"  # Should use error_result
      #   end
      #
      #   # bad
      #   def index
      #     return resources  # Raw data instead of result hash
      #   end
      #
      #   # good
      #   def create
      #     success_result(resource: resource, message: "Created")
      #   end
      #
      #   # good
      #   def update
      #     error_result("Update failed", error_type: :validation_failed)
      #   end
      #
      class ServiceResponseFormat < Base
        MSG_RAW_RETURN = "Services must return success_result() or error_result(), " \
                         "not raw data or custom hashes."

        MSG_RAISE_FOR_CONTROL = "Use error_result() instead of raising exceptions for control flow. " \
                                "Exceptions should only be for unexpected errors."

        def on_def(node)
          return unless in_service_class?
          return if private_method?(node)
          return unless service_action?(node)

          check_return_statements(node)
          check_raises_for_control_flow(node)
        end

        private

        def result_methods
          cop_config.fetch("ResultMethods", %w[success_result error_result unauthorized_error]).map(&:to_sym)
        end

        def in_service_class?
          file_path = processed_source.file_path
          file_path.include?("app/services/") && !file_path.include?("base_service.rb")
        end

        def private_method?(node)
          # Check if method is defined after a 'private' call in the class
          class_node = node.each_ancestor(:class).first
          return false unless class_node

          # Find all 'private' send nodes in the class
          private_nodes = []
          class_node.each_descendant(:send) do |send_node|
            private_nodes << send_node if send_node.method?(:private) && send_node.arguments.empty?
          end

          return false if private_nodes.empty?

          # Check if this method comes after any 'private' declaration
          private_nodes.any? do |private_node|
            node.source_range.begin_pos > private_node.source_range.end_pos &&
              node.parent == private_node.parent # Same scope
          end
        end

        def service_action?(node)
          method_name = node.method_name.to_s

          # Skip private methods (they're helpers)
          parent = node.parent
          if parent&.send_type? && parent.method?(:private)
            # This method was declared after 'private' keyword
            return false
          end

          # Skip helper/utility methods
          return false if helper_method?(method_name)

          # Skip methods that return specific types by convention
          return false if finder_method?(method_name)
          return false if predicate_method?(method_name)
          return false if calculation_method?(method_name)

          # Common CRUD and business actions
          %w[
            index show new create edit update destroy
            execute perform run call
            approve reject publish unpublish
            activate deactivate enable disable
            import export sync refresh
          ].any? { |action| method_name == action } ||
            method_name.match?(/^(batch_|bulk_|mass_|handle_|process_)/)
        end

        def check_return_statements(node)
          each_return(node) do |return_node|
            check_return_value(return_node)
          end

          # Also check implicit returns (last expression)
          check_implicit_return(node)
        end

        def each_return(node, &block)
          return unless node

          if node.return_type?
            yield(node)
          end

          if node.respond_to?(:children)
            node.children.each do |child|
              next unless child.is_a?(Parser::AST::Node)
              each_return(child, &block)
            end
          end
        end

        def check_return_value(return_node)
          value = return_node.children[0]
          return unless value

          # Allow if it's a result method call
          return if result_method_call?(value)

          # Allow if it's a variable that might contain a result
          return if possible_result_variable?(value)

          # Allow guard clauses (return nil, return false, return true)
          return if guard_clause?(value)

          # Allow returning error results
          return if error_result_pattern?(value)

          # Allow early returns in conditionals (unless is represented as if in AST)
          parent = return_node.parent
          return if parent&.if_type?

          # Flag raw data returns
          add_offense(return_node, message: MSG_RAW_RETURN)
        end

        def check_implicit_return(node)
          body = node.body
          return unless body

          last_expression = last_expression_of(body)
          return unless last_expression
          return if last_expression.return_type? # Explicit return already checked

          # Allow if it's a result method call
          return if result_method_call?(last_expression)

          # Allow if it's a conditional that might return results
          return if last_expression.if_type? || last_expression.case_type?

          # Allow if it's a variable that might contain a result
          return if possible_result_variable?(last_expression)

          # Flag if it looks like raw data
          if raw_data_return?(last_expression)
            add_offense(last_expression, message: MSG_RAW_RETURN)
          end
        end

        def last_expression_of(node)
          if node.begin_type? && node.children.any?
            node.children.last
          else
            node
          end
        end

        def result_method_call?(node)
          return false unless node&.send_type?

          result_methods.include?(node.method_name)
        end

        def possible_result_variable?(node)
          return false unless node

          # Variable names that suggest they contain results
          if node.lvar_type? || node.ivar_type?
            var_name = node.children[0].to_s
            var_name.include?("result") || var_name == "response"
          else
            false
          end
        end

        def raw_data_return?(node)
          # Skip nil/false/true/empty values
          return false if node.nil_type? || node.false_type? || node.true_type?
          return false if empty_value?(node)

          # Common patterns of raw data returns
          node.array_type? || # Returning array
            node.const_type? || # Returning constant/class
            (node.send_type? && active_record_query?(node)) || # AR query
            (node.lvar_type? && !possible_result_variable?(node)) # Local var (not result)
        end

        def active_record_query?(node)
          ar_methods = %i[all where find find_by includes joins order limit]
          ar_methods.include?(node.method_name)
        end

        def check_raises_for_control_flow(node)
          each_raise(node) do |raise_node|
            # Skip if in a rescue block (re-raising is ok)
            next if in_rescue_block?(raise_node)

            # Check if it looks like control flow
            if control_flow_exception?(raise_node)
              add_offense(raise_node, message: MSG_RAISE_FOR_CONTROL)
            end
          end
        end

        def each_raise(node, &block)
          return unless node

          if node.send_type? && %i[raise fail].include?(node.method_name)
            yield(node)
          end

          if node.respond_to?(:children)
            node.children.each do |child|
              next unless child.is_a?(Parser::AST::Node)
              each_raise(child, &block)
            end
          end
        end

        def in_rescue_block?(node)
          parent = node.parent
          while parent
            return true if parent.rescue_type? || parent.resbody_type?
            parent = parent.parent
          end
          false
        end

        def control_flow_exception?(raise_node)
          # Common control flow exception patterns
          return false unless raise_node.arguments.any?

          first_arg = raise_node.arguments.first
          if first_arg.str_type?
            message = first_arg.value
            control_flow_messages?(message)
          elsif first_arg.const_type?
            # Standard exceptions used for control flow
            exception_class = first_arg.source
            %w[StandardError RuntimeError].include?(exception_class)
          else
            false
          end
        end

        def control_flow_messages?(message)
          patterns = [
            /not found/i,
            /invalid/i,
            /unauthorized/i,
            /forbidden/i,
            /not allowed/i,
            /cannot/i,
            /must be/i,
            /required/i
          ]

          patterns.any? { |pattern| message.match?(pattern) }
        end

        def helper_method?(method_name)
          # Common helper method patterns
          method_name.start_with?("find_", "get_", "fetch_", "load_") ||
            method_name.end_with?("_params", "_attributes", "_data", "_hash") ||
            %w[params permitted_params service_params].include?(method_name)
        end

        def finder_method?(method_name)
          # Methods that conventionally return model instances
          method_name.start_with?("find_", "get_") ||
            method_name.end_with?("_by_id", "_by_token", "_by_email") ||
            %w[find_resource find_record current_resource resource].include?(method_name)
        end

        def predicate_method?(method_name)
          # Methods that return boolean values
          method_name.end_with?("?") ||
            method_name.start_with?("is_", "has_", "can_", "should_", "valid_", "check_")
        end

        def calculation_method?(method_name)
          # Methods that perform calculations
          method_name.start_with?("calculate_", "compute_", "count_", "sum_") ||
            method_name.end_with?("_count", "_total", "_sum", "_average")
        end

        def guard_clause?(node)
          # Allow return nil, false, true, [] or early returns
          node.nil_type? || node.false_type? || node.true_type? ||
            (node.array_type? && node.children.empty?) ||
            (node.str_type? && node.value.empty?) ||
            (node.hash_type? && node.children.empty?)
        end

        def error_result_pattern?(node)
          # Check if this looks like an error result
          return false unless node.send_type?

          # Check for typed_error_result or similar
          node.method_name.to_s.include?("error") ||
            result_methods.include?(node.method_name)
        end

        def empty_value?(node)
          # Check for empty arrays, hashes, strings
          (node.array_type? && node.children.empty?) ||
            (node.hash_type? && node.children.empty?) ||
            (node.str_type? && node.value.empty?)
        end
      end
    end
  end
end
