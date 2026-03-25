# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw svg() calls and SVG string literals in non-atom GlassMorph components.
      # Molecules and organisms must delegate to the Icon() atom (DEC-030).
      #
      # Atoms are the only layer permitted to contain raw HTML/SVG primitives.
      # Data-driven SVGs (charts, sparklines, brand logos) that cannot use the Icon atom
      # should either be extracted to a dedicated atom or suppressed with a disable comment.
      #
      # @example Bad (in a molecule or organism)
      #   svg(viewBox: "0 0 16 16", fill: "currentColor") do
      #     path(d: "M11.742...")
      #   end
      #
      # @example Bad (in a molecule or organism)
      #   raw '<svg xmlns="http://www.w3.org/2000/svg">...</svg>'.html_safe
      #
      # @example Good
      #   Icon(name: "search")
      #   Icon(name: "chevron-down", class: "expand-icon")
      #
      class NoRawSvgInComponents < Base
        MSG_SVG_CALL = 'Use `Icon(name: "...")` instead of raw `svg()` calls. ' \
                       "Raw SVG belongs only in atom components (DEC-030)."
        MSG_RAW_SVG  = 'Use `Icon(name: "...")` instead of raw SVG strings. ' \
                       "Raw SVG belongs only in atom components (DEC-030)."

        SVG_STRING_PATTERN = /<svg[\s>]/i.freeze

        # Matches Phlex svg() DSL calls: svg(...) { }
        def_node_matcher :svg_call?, <<~PATTERN
          (send nil? :svg ...)
        PATTERN

        # Matches raw("<svg...>") or raw("<svg...>".html_safe)
        def_node_matcher :raw_svg_string?, <<~PATTERN
          (send nil? :raw
            {(str #svg_string?) (send (str #svg_string?) :html_safe)})
        PATTERN

        def on_send(node)
          if svg_call?(node)
            add_offense(node, message: MSG_SVG_CALL)
          elsif raw_svg_string?(node)
            add_offense(node, message: MSG_RAW_SVG)
          end
        end

        private

        def svg_string?(str)
          str.match?(SVG_STRING_PATTERN)
        end
      end
    end
  end
end
