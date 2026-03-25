# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces use of `data:` instead of deprecated data attribute parameters.
      #
      # @example
      #   # bad
      #   FlexColumn(gap: :md, additional_data_attrs: { controller: "x" })
      #   ToggleButton(enabled: true, data_attributes: { action: "click" })
      #
      #   # good
      #   FlexColumn(gap: :md, data: { controller: "x" })
      #   ToggleButton(enabled: true, data: { action: "click" })
      #
      class DataParameter < Base
        extend AutoCorrector

        MSG = "Use `data:` instead of `%<param>s` for NewUI components. " \
              "The standard API uses `data:` for data attributes."

        DEPRECATED_PARAMS = %i[additional_data_attrs data_attributes].freeze

        def_node_matcher :deprecated_data_param?, <<~PATTERN
          (pair (sym ${ :additional_data_attrs :data_attributes }) _)
        PATTERN

        def on_pair(node)
          deprecated_data_param?(node) do |param_name|
            return unless in_glass_morph_context?

            key_node = node.key
            add_offense(key_node, message: format(MSG, param: param_name)) do |corrector|
              key_source = key_node.source
              if key_source.start_with?(":")
                corrector.replace(key_node, ":data")
              else
                new_range = key_node.source_range.resize(key_node.source_range.size + 1)
                corrector.replace(new_range, "data:")
              end
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
