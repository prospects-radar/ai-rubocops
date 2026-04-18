# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw `label()` calls in components that should use the
      # `Label` atom instead.
      #
      # Raw label elements miss the design system's required/optional indicators,
      # validation states, and consistent styling.
      #
      # @example
      #   # bad
      #   label(for: "email", class: "form-label") { "Email" }
      #   label(class: "form-label fw-semibold") { "Name" }
      #
      #   # good
      #   Label(text: "Email", for_input: "email")
      #   Label(text: "Name", for_input: "name", required: true)
      #
      class NoRawLabels < Base
        extend AutoCorrector

        MSG = "Use `Label(text: ..., for_input: ...)` instead of raw `label()`. " \
              "The Label atom provides required/optional indicators and validation states."

        # Classes to strip (the atom adds its own base classes)
        STRIP_CLASSES = /\b(form-label|label)\b/

        def on_send(node)
          return unless raw_label?(node)

          add_offense(node) do |corrector|
            autocorrect_label(corrector, node)
          end
        end

        private

        def raw_label?(node)
          !node.receiver && node.method_name == :label
        end

        def autocorrect_label(corrector, node)
          params = []
          hash_arg = node.arguments.find { |arg| arg.hash_type? }

          # Extract text from block if it's a simple string
          text = extract_simple_text(node)
          params << "text: #{text.inspect}" if text

          if hash_arg
            hash_arg.pairs.each do |pair|
              key = pair.key.value
              value_source = pair.value.source

              case key
              when :for
                # Raw HTML `for:` maps to Label atom's `for_input:`
                params << "for_input: #{value_source}"
              when :class
                remaining = strip_classes(pair.value)
                params << "class: #{remaining}" if remaining
              when :data
                params << "data: #{value_source}"
              when :id
                params << "id: #{value_source}"
              when :style
                params << "style: #{value_source}"
              else
                params << "#{key}: #{value_source}"
              end
            end
          end

          replacement = "Label(#{params.join(', ')})"

          # If block has simple text content, we extracted it into text: param
          if text && node.block_node
            corrector.replace(node.block_node.source_range, replacement)
          elsif node.block_node
            # Complex block — keep the block, replace send part only
            # Build Label call without closing paren, let block continue
            block_replacement = build_with_block(params, node)
            corrector.replace(node.block_node.source_range, block_replacement)
          else
            corrector.replace(node.source_range, replacement)
          end
        end

        def extract_simple_text(node)
          return nil unless node.block_node&.body

          body = node.block_node.body
          return body.value if body.str_type?

          nil
        end

        def build_with_block(params, node)
          block = node.block_node
          body_source = block.body&.source || ""
          block_open = block.braces? ? "{ " : "do\n"
          block_close = block.braces? ? " }" : "\nend"

          "Label(#{params.join(', ')}) #{block_open}#{body_source}#{block_close}"
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
