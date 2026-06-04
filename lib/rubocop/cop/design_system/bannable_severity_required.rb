# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Ensures every class that includes Bannable declares a severity level.
      #
      # @example Bad
      #   class MyBanner < BaseComponent
      #     include Bannable
      #   end
      #
      # @example Good
      #   class MyBanner < BaseComponent
      #     include Bannable
      #     severity :warning
      #   end
      #
      # @example Also Good (instance-level override)
      #   class MyBanner < BaseComponent
      #     include Bannable
      #     def severity = @level
      #   end
      #
      class BannableSeverityRequired < Base
        MSG = "BannableSeverityRequired: class includes Bannable but does not declare `severity`. " \
              "Add `severity :critical`, `:warning`, or `:info`."

        def on_class(node)
          body = node.body
          return unless body
          return unless includes_bannable?(body)
          return if declares_severity?(body)
          return if overrides_severity_method?(body)

          include_node = find_bannable_include(body)
          add_offense(include_node, message: MSG)
        end

        private

        def includes_bannable?(body)
          !find_bannable_include(body).nil?
        end

        def find_bannable_include(body)
          body.each_node(:send).find do |n|
            n.method_name == :include &&
              n.first_argument&.const_type? &&
              n.first_argument.short_name == :Bannable
          end
        end

        def declares_severity?(body)
          body.each_node(:send).any? do |n|
            n.method_name == :severity && !n.receiver
          end
        end

        def overrides_severity_method?(body)
          body.each_node(:def).any? { |n| n.method_name == :severity }
        end
      end
    end
  end
end
