# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects inline `style:` values containing color-related CSS properties
      # and named color parameters with hardcoded hex or CSS-variable values in
      # GlassMorph molecules and organisms.
      #
      # Color rules must live in the component's CSS file, expressed as BEM classes
      # (e.g. `.stakeholder-name`, `.event-title`, `.kanban-column-title`).
      # Inline colour specifications bypass the design-token system and make
      # theme-aware styling impossible.
      #
      # Two violation kinds are detected:
      #
      # 1. `style:` string that contains a colour-related CSS property
      #    (`color`, `background`, `background-color`, etc.)
      # 2. A named colour parameter (`:color`, `:icon_color`, etc.) whose value is
      #    a hardcoded hex string or a CSS `var(--*)` reference (not a symbol variant)
      #
      # @example Bad — inline style with colour property
      #   Heading(level: 3, style: "color: var(--gm-teal-700); margin: 0;") { title }
      #   Box(style: "background: #dc3545; padding: 8px;") { content }
      #   Span(style: "font-size: 13px; color: var(--gm-teal-700); margin-bottom: 5px;") { text }
      #
      # @example Bad — named colour param with hardcoded value
      #   ModalHeader(icon: "warn", icon_color: "#dc3545")
      #   SliderComponent.new(color: "var(--gm-red-500)")
      #
      # @example Good — BEM class carries the colour
      #   Heading(level: 3, class: "stakeholder-name") { title }
      #   Heading(level: 4, class: "event-title") { event[:title] }
      #   ModalHeader(icon: "warn", icon_variant: :danger)
      #
      class NoInlineColorStyles < Base
        MSG_STYLE = "Avoid inline colour styles (`%<prop>s:`). " \
                    "Add a BEM class to the component's CSS file and pass it via `class:` instead."

        MSG_PARAM = "Avoid hardcoded colour value in `%<param>s:`. " \
                    "Use a symbol variant (e.g. `icon_variant: :danger`) or a BEM CSS class instead."

        # CSS properties that must not appear in inline style: strings
        COLOR_CSS_PROPERTIES = %w[
          color background background-color border-color
          outline-color text-decoration-color fill stroke
        ].freeze

        # Named parameters whose string values are colour violations
        COLOR_PARAM_NAMES = %i[color icon_color background_color border_color].freeze

        # Value patterns that flag a named colour parameter
        HEX_COLOR    = /\A#[0-9a-fA-F]{3,8}\z/
        CSS_VARIABLE = /\Avar\(--/
        NAMED_COLOR  = /\A(red|blue|green|white|black|yellow|orange|purple|pink|gray|grey|transparent)\z/i

        def on_pair(node)
          return unless node.pair_type? && node.key.sym_type?

          key = node.key.value
          if key == :style
            check_style_pair(node)
          elsif COLOR_PARAM_NAMES.include?(key)
            check_color_param(node)
          end
        end

        private

        # ── style: "... color: ...; ..." ──────────────────────────────────────

        def check_style_pair(node)
          css = extract_string(node.value)
          return unless css

          color_css_properties_in(css).each do |prop|
            add_offense(node, message: format(MSG_STYLE, prop: prop))
          end
        end

        def color_css_properties_in(css)
          COLOR_CSS_PROPERTIES.select { |prop| css.match?(/\b#{Regexp.escape(prop)}\s*:/) }
        end

        # ── icon_color: "#abc" or color: "var(--gm-red-500)" ─────────────────

        def check_color_param(node)
          value = extract_string(node.value)
          return unless value
          return unless hardcoded_color?(value)

          add_offense(node, message: format(MSG_PARAM, param: node.key.value))
        end

        def hardcoded_color?(str)
          HEX_COLOR.match?(str) || CSS_VARIABLE.match?(str) || NAMED_COLOR.match?(str)
        end

        # ── helpers ───────────────────────────────────────────────────────────

        def extract_string(node)
          return node.value if node.str_type?

          # For interpolated strings join static parts (good enough for colour detection)
          if node.dstr_type?
            return node.children.select(&:str_type?).map(&:value).join
          end

          nil
        end
      end
    end
  end
end
