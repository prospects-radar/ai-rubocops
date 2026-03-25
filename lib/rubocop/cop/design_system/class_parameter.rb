# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces use of `class:` instead of `css_class:` for NewUI components.
      #
      # @example
      #   # bad
      #   Button(text: "Save", css_class: "my-class")
      #
      #   # good
      #   Button(text: "Save", class: "my-class")
      #
      class ClassParameter < Base
        extend AutoCorrector

        MSG = "Use `class:` instead of `css_class:` for NewUI components. " \
              "The standard API uses `class:` for CSS class customization."

        def_node_matcher :css_class_param?, <<~PATTERN
          (pair (sym :css_class) _)
        PATTERN

        def on_pair(node)
          return unless css_class_param?(node)
          return unless in_glass_morph_context?

          key_node = node.key
          add_offense(key_node, message: MSG) do |corrector|
            key_source = key_node.source
            if key_source == ":css_class"
              corrector.replace(key_node, ":class")
            else
              new_range = key_node.source_range.resize(key_node.source_range.size + 1)
              corrector.replace(new_range, "class:")
            end
          end
        end

        private

        def in_glass_morph_context?
          file_path = processed_source.file_path
          file_path.include?("app/views/glass_morph/") ||
            file_path.include?("app/components/glass_morph/") ||
            file_path.include?("spec/components/glass_morph/") ||
            file_path.include?("spec/components/previews/")
        end
      end
    end
  end
end
