# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Enforces that services use rescue_from DSL or structured error handling
      # instead of bare rescue blocks.
      #
      # Bare rescue blocks in services often swallow errors silently or return
      # inconsistent error formats. The rescue_from DSL ensures errors are
      # handled consistently and logged properly.
      #
      # @example
      #   # bad
      #   class MyService < BaseService
      #     private
      #
      #     def create
      #       resource.save!
      #     rescue ActiveRecord::RecordInvalid => e
      #       error_result(e.message)
      #     end
      #   end
      #
      #   # good
      #   class MyService < BaseService
      #     rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
      #
      #     private
      #
      #     def create
      #       resource.save!
      #     end
      #   end
      #
      #   # also good - rescue with error_result in the same block
      #   class MyService < BaseService
      #     private
      #
      #     def create
      #       external_api.call
      #     rescue ExternalApi::Error => e
      #       Rails.logger.error("API failed: #{e.message}")
      #       error_result("External API failure", error_type: :external_error)
      #     end
      #   end
      #
      class ServiceRescueFrom < Base
        MSG = "Prefer `rescue_from` DSL over inline rescue blocks in services. " \
              "If inline rescue is necessary, ensure it returns error_result() and logs the error."

        def on_resbody(node)
          return unless in_service_file?
          return if in_private_helper?(node)
          return if has_error_result_and_logging?(node)

          add_offense(node, message: MSG)
        end

        private

        def in_service_file?
          file_path = processed_source.file_path
          file_path.include?("app/services/") &&
            !file_path.end_with?("base_service.rb") &&
            !file_path.include?("app/services/concerns/")
        end

        def in_private_helper?(node)
          method_node = node.each_ancestor(:def).first
          return false unless method_node

          # Handle class << self (sclass) blocks — check the sclass body for private
          sclass_node = method_node.each_ancestor(:sclass).first
          if sclass_node
            private_found = false
            sclass_node.body&.each_child_node do |child|
              if child.send_type? && child.method?(:private) && child.arguments.empty?
                private_found = true
              end
              return true if child == method_node && private_found
            end
          end

          class_node = method_node.each_ancestor(:class).first
          return false unless class_node

          # Check if method is after private or protected keyword
          private_found = false
          class_node.body&.each_child_node do |child|
            if child.send_type? && child.arguments.empty? &&
               (child.method?(:private) || child.method?(:protected))
              private_found = true
            end

            if child == method_node && private_found
              return true
            end
          end

          false
        end

        def has_error_result_and_logging?(node)
          # Inline rescue (e.g., `expr rescue nil`) — the rescue keyword, exception class,
          # and exception variable are all nil. Accept as safe (not a swallowed-error pattern).
          return true if inline_rescue?(node)

          body = node.body

          has_error_result = false
          has_logging = false
          has_raise = false

          has_error_delegation = false

          search_node(body) do |child|
            if child.send_type?
              has_error_result = true if %i[error_result unauthorized_error].include?(child.method_name)
              has_logging = true if logging_call?(child)
              has_raise = true if child.method_name == :raise
              # Delegation to error/rejection handler methods (e.g., handle_auth_error, handle_message_rejected)
              has_error_delegation = true if child.method_name.to_s.match?(/\Ahandle_/i)
            end
          end

          # Accept structured hash responses with success: false (adapter pattern)
          has_structured_hash = body_returns_success_false_hash?(body)

          # Accept if it has error_result, re-raises, logs the error, delegates to handler, or uses adapter pattern
          has_error_result || has_logging || has_raise || has_error_delegation || has_structured_hash
        end

        def body_returns_success_false_hash?(body)
          return false unless body

          # Check if rescue body (directly or as last statement) is a structured hash response
          nodes_to_check = body.begin_type? ? [ body.children.last ] : [ body ]
          nodes_to_check.any? do |n|
            next false unless n.respond_to?(:type)
            next false unless n.hash_type?

            # Any hash with :success or :valid key is a structured response (not a silent swallow)
            n.pairs.any? do |pair|
              next false unless pair.key.sym_type?
              %i[success valid].include?(pair.key.value)
            end
          end
        end

        def inline_rescue?(node)
          # Inline rescue: `expr rescue value` — resbody has no exception type list (children[0] is nil)
          # and is a direct child of a rescue node that is NOT wrapped in kwbegin
          exception_list = node.children[0]
          return false unless exception_list.nil?

          rescue_node = node.parent
          return false unless rescue_node&.rescue_type?

          # If parent of rescue is kwbegin, it's a begin/rescue/end block, not inline
          !rescue_node.parent&.kwbegin_type?
        end

        def logging_call?(node)
          return false unless node.send_type?

          receiver = node.receiver
          return false unless receiver

          # Rails.logger.error/warn/info or RAAF.logger
          if receiver.send_type?
            receiver_name = receiver.source
            return true if receiver_name.match?(/logger/i)
          end

          false
        end

        def search_node(node, &block)
          return unless node.is_a?(Parser::AST::Node)

          yield(node)

          node.children.each do |child|
            search_node(child, &block)
          end
        end
      end
    end
  end
end
