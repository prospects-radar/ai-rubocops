# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Prevents authorization logic in controller actions (business logic)
      #
      # @example
      #   # bad
      #   def create
      #     authorize! :create, Company
      #     @company = Company.create(params)
      #   end
      #
      #   # good
      #   def create
      #     auto_service_call  # Service handles authorization
      #   end
      #
      class NoControllerAuthorization < Base
        MSG = "Avoid authorization logic in controllers. Move to services per DEC-013"

        def_node_matcher :in_action_method?, <<~PATTERN
          (def {
            :index :show :new :create :edit :update :destroy
            :search :export :import
          } ...)
        PATTERN

        def on_send(node)
          return unless in_controller_file?
          return unless authorization_methods.include?(node.method_name)
          return unless inside_action_method?(node)

          add_offense(node)
        end

        private

        def authorization_methods
          cop_config.fetch("AuthorizationMethods", %w[authorize! can? cannot? accessible_by]).map(&:to_sym)
        end

        def in_controller_file?
          processed_source.path.include?("app/controllers/")
        end

        def inside_action_method?(node)
          node.each_ancestor(:def).any? { |ancestor| in_action_method?(ancestor) }
        end
      end
    end
  end
end
