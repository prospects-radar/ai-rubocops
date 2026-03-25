# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Enforces meta-programming action dispatch pattern (DEC-031).
      # Services should NOT define call method with case/when dispatch.
      # BaseService handles dispatch automatically.
      #
      # @example
      #   # bad - Old pattern (deprecated)
      #   class MyService < BaseService
      #     def call
      #       case params[:action]
      #       when :index then index
      #       when :show then show
      #       end
      #     end
      #   end
      #
      #   # good - New pattern (current)
      #   class MyService < BaseService
      #     # No call method - automatic dispatch!
      #
      #     private
      #
      #     def index
      #       success_result(resources: Resource.all)
      #     end
      #
      #     def show
      #       success_result(resource: find_resource)
      #     end
      #   end
      #
      class ServiceActionDispatch < Base
        extend AutoCorrector

        MSG = "Do not implement manual action dispatch in call method. " \
              "BaseService provides automatic action dispatch (DEC-031). " \
              "Remove the call method and define action methods directly."

        def_node_matcher :call_method_with_case?, <<~PATTERN
          (def :call _#{' '}
            {
              (case (send (send nil? :params) :[] (sym :action)) ...)
              (case (send (send (send nil? :params) :[] (sym :action)) {:to_sym :to_s}) ...)
              (case (send (send (send nil? :params) :[] (str "action")) {:to_sym :to_s}) ...)
              (begin <(case (send (send nil? :params) :[] (sym :action)) ...) ...>)
            }
          )
        PATTERN

        def on_def(node)
          return unless call_method_with_case?(node)
          return unless in_service_class?

          add_offense(node, message: MSG) do |corrector|
            # Remove the entire call method
            corrector.remove(node)

            # Add a comment explaining the change
            corrector.insert_before(node, "# Action methods are dispatched automatically by BaseService\n")
          end
        end

        private

        def in_service_class?
          file_path = processed_source.file_path
          file_path.include?("app/services/") && !file_path.include?("base_service.rb")
        end
      end
    end
  end
end
