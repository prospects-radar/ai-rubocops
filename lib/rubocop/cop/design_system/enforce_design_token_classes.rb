# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects legacy Bootstrap text/color classes that should use gm-* design tokens.
      #
      # After the Glass Morph migration, components should use gm-* utility classes
      # that automatically adapt to light/dark surface contexts instead of legacy
      # Bootstrap text color classes.
      #
      # @example Bad
      #   span(class: "text-white") { name }
      #   span(class: "text-muted") { description }
      #   span(class: "text-dark") { title }
      #
      # @example Good
      #   span(class: "gm-text-primary") { name }
      #   span(class: "gm-text-muted") { description }
      #   span(class: "gm-text-primary") { title }
      #
      class EnforceDesignTokenClasses < Base
        LEGACY_CLASSES = {
          "text-white" => "gm-text-primary (on dark surface)",
          "text-muted" => "gm-text-muted",
          "text-dark" => "gm-text-primary (on light surface)",
          "text-secondary" => "gm-text-secondary",
          "text-light" => "gm-text-primary (on dark surface)"
        }.freeze

        LEGACY_PATTERN = /\b(text-white|text-muted|text-dark|text-secondary|text-light)\b/

        def on_send(node)
          return unless in_glass_morph_scope?
          return unless phlex_html_method?(node)

          classes = class_value(node)
          return unless classes

          classes.scan(LEGACY_PATTERN).flatten.each do |legacy_class|
            replacement = LEGACY_CLASSES[legacy_class]
            msg = "Use #{replacement} instead of #{legacy_class}. " \
                  "See docs/plans/2026-03-04-ui-consistency-analysis.md Part 9."
            add_offense(node, message: msg)
          end
        end

        private

        def phlex_html_method?(node)
          return false if node.receiver

          %i[div span button a i p h1 h2 h3 h4 h5 h6 label td th li
             nav ul ol strong em small].include?(node.method_name)
        end

        def class_value(node)
          return nil unless node.arguments.any?

          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return nil unless hash_arg

          class_pair = hash_arg.pairs.find { |pair| pair.key.value == :class }
          return nil unless class_pair

          value_node = class_pair.value
          if value_node.str_type?
            value_node.value
          elsif value_node.dstr_type?
            value_node.children.select(&:str_type?).map(&:value).join
          end
        end

        def in_glass_morph_scope?
          path = processed_source.file_path
          path.include?("app/views/") || path.include?("app/components/")
        end
      end
    end
  end
end
