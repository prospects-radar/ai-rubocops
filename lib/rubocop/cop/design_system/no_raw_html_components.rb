# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces use of design system components instead of raw HTML in Phlex components.
      #
      # All Phlex components must be composed of design system atoms, molecules, and organisms
      # exclusively. Raw HTML methods (div, span, button, input, etc.) bypass the design system's
      # styling, accessibility, and consistency guarantees.
      #
      # @example
      #   # bad - raw HTML
      #   div(class: "card") { "Content" }
      #   button(type: "submit") { "Click" }
      #   input(type: "text")
      #   span(class: "badge") { "New" }
      #
      #   # good - design system components
      #   GlassCard { "Content" }
      #   Button(text: "Click", variant: :primary)
      #   Input(name: "field", type: :text)
      #   Badge.label("New")
      #
      class NoRawHtmlComponents < Base
        MSG = "Use design system components instead of raw `%{method}()` HTML. " \
              "See .claude/skills/design-system/SKILL.md#component-catalog for available components."

        # HTML methods that must use design system components
        HTML_METHODS = %i[
          div span button input select textarea a img svg form fieldset label
          h1 h2 h3 h4 h5 h6 p strong em ul ol li table tr td th thead tbody tfoot
          nav section article header footer aside blockquote pre code
          i section main
        ].freeze

        def on_send(node)
          return unless raw_html_method?(node)
          return if whitelisted_context?(node)
          return if ancestor_is_svg_or_exception?(node)

          add_offense(node, message: format(MSG, method: node.method_name))
        end

        private

        def raw_html_method?(node)
          # Only flag methods without receiver (not method calls on objects)
          !node.receiver && HTML_METHODS.include?(node.method_name)
        end

        def whitelisted_context?(node)
          path = processed_source.file_path

          # Allow raw HTML in:
          # 1. Base components (internal helpers)
          # 2. Styleguide/documentation
          # 3. Legacy/old UI components
          # 4. Preline (being phased out)
          # 5. RuboCop specs
          path.include?("base_component.rb") ||
            path.include?("styleguide/") ||
            path.include?("app/components/preline/") ||
            path.include?("legacy/") ||
            path.include?("spec/")
        end

        # Allow SVG internals (svg { path(...) }, svg { g(...) })
        # Allow exceptions in specific methods like render_odoo, render_image, render_*
        def ancestor_is_svg_or_exception?(node)
          # Don't flag <path>, <g>, <circle>, etc. inside <svg> blocks
          ancestor_svg = node.each_ancestor(:send).find do |ancestor|
            ancestor.method_name == :svg
          end
          return true if ancestor_svg

          # Allow in render_* methods that produce brand logos or data visualizations
          method_def = node.each_ancestor(:def).first
          return true if method_def && method_def.method_name.to_s.start_with?("render_")

          false
        end
      end
    end
  end
end
