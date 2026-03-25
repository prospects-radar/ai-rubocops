# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Blocks new Preline component usage in ALL new code.
      #
      # Preline is deprecated and scheduled for removal. All new views and
      # components must use GlassMorph (Bootstrap 5) components instead.
      #
      # Existing legacy views are excluded via the Exclude list below.
      # As each legacy view is migrated to GlassMorph, remove it from the Exclude list.
      #
      # @example
      #   # bad - anywhere in the codebase
      #   render Components::Preline::Card.new
      #   render Components::Preline::Button.new(text: "Save")
      #
      #   # good - use GlassMorph components
      #   GlassCard(padding: :md) { ... }
      #   Button(text: "Save", variant: :primary)
      #
      class NoNewPrelineUsage < Base
        MSG = "Preline is deprecated. Use GlassMorph components instead " \
              "(Button, GlassCard, Icon, etc.). See docs/plans/2026-03-04-ui-consistency-analysis.md"

        PRELINE_PATTERN = /Components::Preline/

        def on_const(node)
          const_name = node.source
          return unless const_name.match?(PRELINE_PATTERN)

          add_offense(node)
        end
      end
    end
  end
end
