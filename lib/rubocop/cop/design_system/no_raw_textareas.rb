# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw `textarea()` calls in components that should use the
      # `TextArea` atom instead.
      #
      # Raw textarea elements miss the design system's gradient focus effect,
      # validation states, and consistent styling.
      #
      # @example
      #   # bad
      #   textarea(name: "description", rows: 5, class: "form-control") { value }
      #
      #   # good
      #   TextArea(name: "description", rows: 5, value: value)
      #
      class NoRawTextareas < Base
        extend AutoCorrector

        MSG = "Use `TextArea(name: ..., rows: ...)` instead of raw `textarea()`. " \
              "The TextArea atom provides gradient focus effects and validation states."

        # Attributes that map directly to TextArea params
        DIRECT_PARAMS = %i[name rows placeholder required disabled readonly id].freeze

        # Classes to strip (the atom adds its own base classes)
        STRIP_CLASSES = /\b(form-control|textarea)\b/

        def on_send(node)
          return unless raw_textarea?(node)

          add_offense(node) do |corrector|
            autocorrect_textarea(corrector, node)
          end
        end

        private

        def raw_textarea?(node)
          !node.receiver && node.method_name == :textarea
        end

        def autocorrect_textarea(corrector, node)
          params = []
          hash_arg = node.arguments.find { |arg| arg.hash_type? }

          if hash_arg
            hash_arg.pairs.each do |pair|
              key = pair.key.value
              value_source = pair.value.source

              if DIRECT_PARAMS.include?(key)
                params << "#{key}: #{value_source}"
              elsif key == :class
                remaining = strip_classes(pair.value)
                params << "class: #{remaining}" if remaining
              elsif key == :data
                params << "data: #{value_source}"
              elsif key == :style
                params << "style: #{value_source}"
              else
                params << "#{key}: #{value_source}"
              end
            end
          end

          # Extract block content as value param
          block_value = extract_block_value(node)
          params << "value: #{block_value}" if block_value

          replacement = "TextArea(#{params.join(', ')})"

          # Replace the entire node including block
          range = node.block_node ? node.block_node.source_range : node.source_range
          corrector.replace(range, replacement)
        end

        def extract_block_value(node)
          return nil unless node.block_node&.body

          body = node.block_node.body
          # Simple expression in block: textarea(name: "x") { @value }
          body.source
        end

        def strip_classes(value_node)
          return nil unless value_node.str_type?

          cleaned = value_node.value.gsub(STRIP_CLASSES, "").squeeze(" ").strip
          return nil if cleaned.empty?

          "\"#{cleaned}\""
        end
      end
    end
  end
end
