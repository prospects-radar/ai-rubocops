# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Warns when multiple primary buttons appear in a single component file.
      #
      # Each section/component should have at most one primary call-to-action.
      # Additional actions should use :secondary or :tertiary variants.
      #
      # @example Bad
      #   Button(text: "Save", variant: :primary)
      #   Button(text: "Also Save", variant: :primary)  # second primary!
      #
      # @example Good
      #   Button(text: "Save", variant: :primary)
      #   Button(text: "Cancel", variant: :secondary)
      #
      class SinglePrimaryButtonPerSection < Base
        MSG = "Multiple primary buttons detected. Use :secondary or :tertiary for additional actions."

        def on_new_investigation
          @primary_button_nodes = []
        end

        def on_send(node)
          return unless button_with_primary_variant?(node)

          @primary_button_nodes << node
        end

        def on_investigation_end
          return if @primary_button_nodes.length <= 1

          # Flag all but the first primary button
          @primary_button_nodes[1..].each do |node|
            add_offense(node, message: MSG)
          end
        end

        private

        def button_with_primary_variant?(node)
          return false if node.receiver
          return false unless node.method_name == :Button
          return false unless node.arguments.any?

          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return false unless hash_arg

          variant_pair = hash_arg.pairs.find { |pair| pair.key.value == :variant }
          return false unless variant_pair

          variant_pair.value.sym_type? && variant_pair.value.value == :primary
        end
      end
    end
  end
end
