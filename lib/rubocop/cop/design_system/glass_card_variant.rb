# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces supported `GlassCard` variants.
      #
      # This keeps call sites aligned with the current GlassMorph component API.
      # Dynamic values are ignored; this cop only flags explicit literal variants.
      #
      # @example Bad
      #   GlassCard(variant: :default)
      #   GlassCard(variant: :minimal)
      #
      # @example Good
      #   GlassCard(variant: :glass)
      #   GlassCard(variant: :solid)
      #   GlassCard(variant: :section)
      #   GlassCard(variant: :elevated)
      class GlassCardVariant < Base
        MSG = "Use a supported GlassCard variant: :glass, :solid, :section, or :elevated."
        ALLOWED_VARIANTS = %i[glass solid section elevated].freeze

        def_node_matcher :glass_card_variant_pair?, <<~PATTERN
          (send nil? :GlassCard (hash <$(pair (sym :variant) $_) ...>))
        PATTERN

        def on_send(node)
          glass_card_variant_pair?(node) do |pair_node, value_node|
            next unless literal_variant?(value_node)
            next if ALLOWED_VARIANTS.include?(variant_value(value_node))

            add_offense(pair_node, message: MSG)
          end
        end

        private

        def literal_variant?(node)
          node.sym_type? || node.str_type?
        end

        def variant_value(node)
          node.value.to_sym
        end
      end
    end
  end
end
