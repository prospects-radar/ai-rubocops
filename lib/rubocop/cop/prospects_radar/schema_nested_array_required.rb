# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Ensures nested array fields in RAAF schemas include `required: true`
      #
      # RAAF requires nested array properties to explicitly mark the field
      # as required, even if the parent object is required. Without this,
      # validation silently fails.
      #
      # @example
      #   # bad
      #   class MySchema
      #     def self.build
      #       {
      #         type: "object",
      #         properties: {
      #           items: {
      #             type: "array",
      #             items: { type: "string" }
      #             # Missing: required: true
      #           }
      #         }
      #       }
      #     end
      #   end
      #
      #   # good
      #   class MySchema
      #     def self.build
      #       {
      #         type: "object",
      #         properties: {
      #           items: {
      #             type: "array",
      #             items: { type: "string" },
      #             required: true
      #           }
      #         }
      #       }
      #     end
      #   end
      #
      class SchemaNestedArrayRequired < Base
        extend AutoCorrector

        MSG = "Nested array fields must include `required: true` for RAAF validation"

        def_node_search :find_array_hashes, <<~PATTERN
          (hash (pair (sym :type) (str "array")) ...)
        PATTERN

        def_node_search :has_required_true?, <<~PATTERN
          (pair (sym :required) (true))
        PATTERN

        def on_hash(node)
          return unless in_schema_file?
          return unless nested_array_hash?(node)
          return if has_required_true?(node)

          add_offense(node) do |corrector|
            autocorrect(corrector, node)
          end
        end

        private

        def in_schema_file?
          path = processed_source.path
          path.include?("app/ai/") &&
            (path.include?("/schemas/") || path.include?("_schema.rb"))
        end

        def nested_array_hash?(node)
          # Check if this hash has type: "array"
          type_pair = node.pairs.find do |pair|
            pair.key.sym_type? &&
            pair.key.value == :type &&
            pair.value.str_type? &&
            pair.value.value == "array"
          end

          return false unless type_pair

          # Check if it has an items key (indicates nested structure)
          items_pair = node.pairs.find do |pair|
            pair.key.sym_type? && pair.key.value == :items
          end

          !!items_pair
        end

        def autocorrect(corrector, node)
          # Add required: true as last pair in hash
          last_pair = node.pairs.last
          corrector.insert_after(
            last_pair.loc.expression,
            ",\n#{' ' * (node.loc.column + 2)}required: true"
          )
        end
      end
    end
  end
end
