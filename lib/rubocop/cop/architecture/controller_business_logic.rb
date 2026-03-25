# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Prevents business logic in controllers - enforces zero-logic delegation (DEC-013).
      #
      # Controllers must be thin wrappers that only delegate to services.
      # All business logic, including validation, authorization, and database operations,
      # belongs in services.
      #
      # @example
      #   # bad - Business logic in controller
      #   class ProductsController < ApplicationController
      #     def create
      #       @product = Product.new(product_params)
      #       if @product.valid?
      #         @product.save!
      #         redirect_to @product
      #       else
      #         render :new
      #       end
      #     end
      #   end
      #
      #   # bad - Authorization in controller
      #   def destroy
      #     authorize! :destroy, Product
      #     @product.destroy
      #     redirect_to products_path
      #   end
      #
      #   # good - Thin delegation
      #   class ProductsController < ApplicationController
      #     include AutoServiceResponse
      #
      #     def create
      #       auto_service_call
      #     end
      #   end
      #
      class ControllerBusinessLogic < Base
        MSG_DATABASE = "Controllers must not perform database operations. " \
                       "Use services for all business logic (DEC-013)."

        MSG_VALIDATION = "Controllers must not perform validation. " \
                         "Move validation logic to services (DEC-013)."

        MSG_AUTHORIZATION = "Controllers must not perform authorization checks. " \
                            "Authorization is business logic and belongs in services (DEC-013)."

        MSG_COMPLEX_LOGIC = "Controllers must not contain complex conditional logic. " \
                            "Use auto_service_call or service delegation helpers (DEC-013)."

        def on_send(node)
          return unless in_controller_action?

          check_database_operations(node)
          check_validation(node)
          check_authorization(node)
        end

        def on_def(node)
          return unless in_controller_action?
          return unless controller_action?(node)

          check_complex_logic(node)
        end

        private

        def database_methods
          cop_config.fetch("DatabaseMethods", %w[
            save save! create create! update update! update_attribute update_attributes
            update_attributes! update_column update_columns destroy destroy! destroy_all
            delete delete_all find_or_create_by find_or_create_by! find_or_initialize_by
            first_or_create first_or_create! first_or_initialize increment! decrement!
            toggle! touch transaction
          ]).map(&:to_sym)
        end

        def validation_methods
          cop_config.fetch("ValidationMethods", %w[valid? invalid? errors validate]).map(&:to_sym)
        end

        def authorization_methods
          cop_config.fetch("AuthorizationMethods", %w[authorize! can? cannot? authorize]).map(&:to_sym)
        end

        def excluded_controllers
          cop_config.fetch("ExcludedControllers", %w[
            application_controller.rb
            api_controller.rb
            api/v1/base_controller.rb
          ])
        end

        def in_controller_action?
          file_path = processed_source.file_path
          return false unless file_path.include?("app/controllers/")
          return false if excluded_controllers.any? { |excluded| file_path.end_with?(excluded) }
          return false if file_path.include?("/concerns/")

          true
        end

        def controller_action?(node)
          # Common controller action names
          action_names = %i[
            index show new create edit update destroy
            approve reject publish unpublish archive restore
            toggle activate deactivate enable disable
          ]

          action_names.include?(node.method_name) ||
            node.method_name.to_s.match?(/^(batch_|bulk_|mass_)/)
        end

        def check_database_operations(node)
          return unless database_methods.include?(node.method_name)

          # Allow if it's on a form builder or other non-model object
          receiver = node.receiver
          return unless receiver
          return if form_builder?(receiver)

          # Allow session operations (for OAuth flows, etc.)
          return if session_operation?(receiver)

          # Allow turbo_stream operations
          return if turbo_stream_operation?(receiver)

          add_offense(node, message: MSG_DATABASE)
        end

        def check_validation(node)
          return unless validation_methods.include?(node.method_name)

          receiver = node.receiver
          return unless receiver
          return if form_builder?(receiver)

          # Allow accessing result.errors or result[:errors] from service calls
          return if service_result_errors?(receiver)

          # Allow exception.record.errors in error handlers
          return if exception_errors?(receiver)

          # Allow resource.errors.add in Devise controllers
          return if devise_error_handling?(node)

          add_offense(node, message: MSG_VALIDATION)
        end

        def check_authorization(node)
          return unless authorization_methods.include?(node.method_name)

          add_offense(node, message: MSG_AUTHORIZATION)
        end

        def check_complex_logic(node)
          # Count nested conditionals
          conditional_depth = count_conditional_depth(node)

          # If action has more than 2 levels of nested conditionals, it's too complex
          if conditional_depth > 2
            add_offense(node.loc.name, message: MSG_COMPLEX_LOGIC)
          end

          # Also check for actions with more than 10 lines (excluding simple variable assignments)
          body_lines = count_logic_lines(node.body)
          if body_lines > 10
            add_offense(node.loc.name, message: MSG_COMPLEX_LOGIC)
          end
        end

        def count_conditional_depth(node, current_depth = 0)
          return current_depth unless node

          max_depth = current_depth

          if conditional_node?(node)
            current_depth += 1
          end

          if node.respond_to?(:children)
            node.children.each do |child|
              next unless child.is_a?(Parser::AST::Node)
              child_depth = count_conditional_depth(child, current_depth)
              max_depth = [ max_depth, child_depth ].max
            end
          end

          max_depth
        end

        def conditional_node?(node)
          node.if_type? || node.case_type? || node.when_type?
        end

        def count_logic_lines(node, count = 0)
          return count unless node

          # Don't count simple variable assignments or render/redirect calls
          unless simple_statement?(node)
            count += 1 if logic_statement?(node)
          end

          if node.respond_to?(:children)
            node.children.each do |child|
              next unless child.is_a?(Parser::AST::Node)
              count = count_logic_lines(child, count)
            end
          end

          count
        end

        def simple_statement?(node)
          # Variable assignment without method calls
          (node.lvasgn_type? || node.ivasgn_type?) && !contains_send?(node)
        end

        def logic_statement?(node)
          node.send_type? || node.if_type? || node.case_type?
        end

        def contains_send?(node)
          return false unless node

          return true if node.send_type?

          if node.respond_to?(:children)
            node.children.any? do |child|
              child.is_a?(Parser::AST::Node) && contains_send?(child)
            end
          else
            false
          end
        end

        def form_builder?(node)
          # Common form builder variable names
          return true if node.lvar_type? && %i[form f].include?(node.children[0])

          false
        end

        def session_operation?(node)
          # Check if this is a session operation
          node.send_type? && node.method?(:session)
        end

        def turbo_stream_operation?(node)
          # Check if this is a turbo_stream operation
          node.send_type? && node.method?(:turbo_stream)
        end

        def service_result_errors?(node)
          # Allow result.errors or result[:errors] patterns
          return false unless node

          # Check if the node itself is named 'result', 'response', or 'outcome'
          if node.lvar_type? || node.ivar_type?
            var_name = node.children[0].to_s
            return true if %w[result response outcome].include?(var_name)
          end

          # Check if it's a method chain like service.run.errors
          # In this case, node would be a send node
          if node.send_type?
            # Check if the final receiver in the chain is a service call
            receiver = node.receiver
            return service_result_errors?(receiver) if receiver
          end

          false
        end

        def exception_errors?(node)
          # Allow exception.record.errors pattern
          return false unless node.send_type? && node.method?(:record)

          receiver = node.receiver
          return false unless receiver&.lvar_type?

          var_name = receiver.children[0].to_s
          %w[exception e ex error].include?(var_name)
        end

        def devise_error_handling?(node)
          # Allow resource.errors.add in Devise controllers
          return false unless node.send_type? && node.method?(:add)

          receiver = node.receiver
          return false unless receiver&.send_type? && receiver.method?(:errors)

          resource = receiver.receiver
          return false unless resource&.lvar_type?

          var_name = resource.children[0].to_s
          %w[resource user].include?(var_name)
        end
      end
    end
  end
end
