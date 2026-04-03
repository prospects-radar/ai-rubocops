# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects stale `NewUi` / `new_ui` references in Ruby source.
      #
      # This catches outdated namespace references in components, views, specs,
      # and Ruby-based docs/examples so newly copied code uses the current
      # GlassMorph naming.
      #
      # @example Bad
      #   render Components::NewUi::Atoms::Icon.new(name: "home")
      #   "app/components/new_ui/molecules/region_select.rb"
      #
      # @example Good
      #   render Components::GlassMorph::Atoms::Icon.new(name: "home")
      #   "app/components/glass_morph/molecules/region_select.rb"
      class NoLegacyNewUiReference < Base
        MSG = "Use `GlassMorph` / `glass_morph` references instead of legacy `NewUi` / `new_ui` naming."
        LEGACY_PATTERN = /\bNewUi\b|\bnew_ui\b|Components::NewUi/.freeze

        def on_const(node)
          return if node.parent&.const_type?

          add_offense(node, message: MSG) if LEGACY_PATTERN.match?(node.source)
        end

        def on_str(node)
          add_offense(node, message: MSG) if LEGACY_PATTERN.match?(node.value)
        end

        def on_dstr(node)
          add_offense(node, message: MSG) if LEGACY_PATTERN.match?(node.source)
        end
      end
    end
  end
end
