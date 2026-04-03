# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects embedded CSS in GlassMorph layouts.
      #
      # Layout-local CSS blocks drift away from the stylesheet tree and make
      # visual regressions harder to reason about. Keep stable CSS in
      # `app/assets/stylesheets/glass_morph/**` and reserve inline style tags
      # for asset pipeline edge cases such as token bootstrapping.
      #
      # @example Bad
      #   style do
      #     raw ".auth-page { min-height: 100vh; }"
      #   end
      #
      # @example Good
      #   stylesheet_link_tag "glass_morph/styles"
      #   style { raw File.read(variables_path).html_safe }
      class NoEmbeddedCssInLayouts < Base
        MSG = "Do not embed CSS in GlassMorph layouts. Move stable rules into the GlassMorph stylesheet tree."
        CSS_PATTERN = /[.#][\w-]+\s*\{|[\w-]+\s*:\s*[^;]+;?/.freeze

        def_node_matcher :style_call?, <<~PATTERN
          (send nil? :style ...)
        PATTERN

        def on_send(node)
          return unless style_call?(node)
          return unless css_literal?(node)

          add_offense(node, message: MSG)
        end

        private

        def css_literal?(node)
          node.arguments.any? { |arg| css_string_node?(arg) } ||
            style_block_contains_css?(node)
        end

        def style_block_contains_css?(node)
          parent = node.parent
          return false unless parent&.block_type?
          return false unless parent.send_node.equal?(node)

          parent.each_descendant(:str, :dstr).any? { |child| css_string_node?(child) }
        end

        def css_string_node?(node)
          return false unless node.str_type? || node.dstr_type?

          CSS_PATTERN.match?(node.source)
        end
      end
    end
  end
end
