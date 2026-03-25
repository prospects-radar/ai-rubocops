# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Prevents services from accepting current_user or current_ability as initialization parameters.
      #
      # Services should access Current.current_user internally, not receive it as a parameter.
      # This enforces Critical Rule #4 from AGENTS.md.
      #
      # @example
      #   # bad
      #   class MyService < BaseService
      #     def initialize(params:, current_user:)
      #       @current_user = current_user
      #     end
      #   end
      #
      #   # bad - in controller
      #   MyService.new(params: params, current_user: current_user).call
      #
      #   # good
      #   class MyService < BaseService
      #     def initialize(params:)
      #       @params = params
      #       # Access current_user via Current.current_user internally
      #     end
      #   end
      #
      #   # good - in controller
      #   MyService.new(params: params).call
      #
      #   # acceptable - defaulting to Current.current_user
      #   def initialize(params:, user: Current.current_user)
      #     @user = user
      #   end
      #
      class NoCurrentUserParameter < Base
        extend AutoCorrector

        MSG_CURRENT_USER = "Services must not accept current_user as a parameter. " \
                           "Access it via Current.current_user internally instead."

        MSG_CURRENT_ABILITY = "Services must not accept current_ability as a parameter. " \
                              "Use can? helper or current_ability internally instead."

        # Services that are excluded (authentication/SSO contexts)
        EXCLUDED_SERVICES = %w[
          AuthenticationService
          SsoAuthenticationService
          Sso::AuthenticationService
        ].freeze

        def on_def(node)
          return unless initialize_method?(node)
          return unless in_service_class?
          return if excluded_service?

          node.arguments.each do |arg|
            check_parameter(node, arg)
          end
        end

        private

        def initialize_method?(node)
          node.method?(:initialize)
        end

        def in_service_class?
          file_path = processed_source.file_path
          file_path.include?("app/services/")
        end

        def excluded_service?
          file_path = processed_source.file_path
          EXCLUDED_SERVICES.any? { |service| file_path.include?(service.underscore) }
        end

        def check_parameter(node, arg)
          return unless keyword_argument?(arg)

          param_name = parameter_name(arg)
          return unless param_name

          case param_name
          when :current_user
            check_current_user_parameter(node, arg)
          when :current_ability
            add_offense(arg, message: MSG_CURRENT_ABILITY)
          end
        end

        def keyword_argument?(arg)
          arg.kwarg_type? || arg.kwoptarg_type? || arg.kwrestarg_type?
        end

        def parameter_name(arg)
          if arg.kwarg_type? || arg.kwoptarg_type?
            arg.children[0]
          elsif arg.kwrestarg_type? && arg.children[0]
            arg.children[0]
          end
        end

        def check_current_user_parameter(node, arg)
          # Allow if it defaults to Current.current_user
          if arg.kwoptarg_type? && defaults_to_current_user?(arg)
            return
          end

          add_offense(arg, message: MSG_CURRENT_USER) do |corrector|
            # Remove the parameter from the method signature
            remove_parameter(corrector, node, arg)
          end
        end

        def defaults_to_current_user?(arg)
          default_value = arg.children[1]
          return false unless default_value

          # Check if default is Current.current_user
          default_value.send_type? &&
            default_value.receiver&.const_type? &&
            default_value.receiver.source == "Current" &&
            default_value.method?(:current_user)
        end

        def remove_parameter(corrector, method_node, param_node)
          # This is complex and would need to handle comma placement
          # For now, just flag the issue without auto-correction
        end
      end
    end
  end
end
