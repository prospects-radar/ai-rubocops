# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects inline `style:` attributes in GlassMorph components and views.
      #
      # Inline styles bypass the design system's CSS classes and design tokens,
      # making the UI harder to maintain and inconsistent. Use CSS classes,
      # Bootstrap utilities, or `var(--gm-*)` custom properties in stylesheets instead.
      #
      # @example Bad
      #   div(style: "width: 40px; height: 40px; background: var(--gm-blue-overlay-8);")
      #   span(style: "color: var(--gm-gray-500);")
      #   Section(style: "box-shadow: 0 1px 3px var(--gm-glass-black-8);")
      #
      # @example Good
      #   div(class: "gm-icon-circle")
      #   span(class: "gm-text-muted")
      #   Section(class: "gm-card-shadow")
      #
      class NoInlineStyles < Base
        MSG = "Avoid inline `style:` attributes. Use CSS classes or design tokens in stylesheets instead."

        # File-level filtering is handled by Include/Exclude in .rubocop.yml.
        def on_pair(node)
          return unless style_pair?(node)
          return unless css_value?(node.value)

          add_offense(node)
        end

        # Also catch style constants that embed inline CSS:
        #   CARD_STYLE = "box-shadow: 0 1px 3px ..."
        def on_casgn(node)
          value = node.children[2]
          return unless value

          # Direct string constant
          if value.str_type? && looks_like_css?(value.value)
            add_offense(node)
          # String interpolation constant: "#{CARD_STYLE} padding: 1.5rem;"
          elsif value.dstr_type? && looks_like_css?(value.source)
            add_offense(node)
          end
        end

        private

        def style_pair?(node)
          return false unless node.pair_type?
          return false unless node.key.sym_type?

          node.key.value == :style
        end

        # Only flag values that are actual CSS strings or interpolated strings.
        # Skip symbols (:bootstrap), variables, and method calls — these are
        # component parameters, not inline CSS.
        def css_value?(value_node)
          return true if value_node.str_type?
          return true if value_node.dstr_type?
          false
        end

        # Heuristic: contains CSS property-value patterns
        def looks_like_css?(str)
          str.match?(/[\w-]+\s*:\s*[^;]+;?/)
        end
      end
    end
  end
end
