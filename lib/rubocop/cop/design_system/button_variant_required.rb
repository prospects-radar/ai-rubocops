# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Ensures Button component usage always specifies an explicit variant.
      #
      # Buttons without a variant default to an ambiguous style. Every Button
      # must explicitly declare its intent via :primary, :secondary, :tertiary,
      # or :danger.
      #
      # @example Bad
      #   Button(text: "Save")
      #   Button(text: "Save", variant: :default)
      #
      # @example Good
      #   Button(text: "Save", variant: :primary)
      #   Button(text: "Cancel", variant: :secondary)
      #   Button(text: "Delete", variant: :danger)
      #
      class ButtonVariantRequired < Base
        MSG = "Button must specify an explicit variant (:primary, :secondary, :tertiary, :danger). " \
              "See docs/plans/2026-03-04-ui-consistency-analysis.md Part 11."

        # Match Button() calls (Phlex component rendering)
        def on_send(node)
          return unless button_component_call?(node)

          variant = extract_variant(node)

          if variant.nil?
            add_offense(node, message: MSG)
          elsif variant == :default
            add_offense(node, message: MSG)
          end
        end

        private

        def button_component_call?(node)
          return false if node.receiver

          node.method_name == :Button
        end

        def extract_variant(node)
          return nil unless node.arguments.any?

          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return nil unless hash_arg

          variant_pair = hash_arg.pairs.find { |pair| pair.key.value == :variant }
          return nil unless variant_pair

          # Dynamic expressions (method calls, ternaries, variables) are trusted —
          # only literal :default is flagged.
          return :dynamic unless variant_pair.value.sym_type?

          variant_pair.value.value
        end
      end
    end
  end
end
