# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Enforces strict I18n mode - no default parameters allowed.
      #
      # Strict I18n mode is enabled, so all translations must exist in locale files.
      # Using default: parameter will cause errors in production.
      #
      # @example
      #   # bad
      #   I18n.t("key", default: "English text")
      #   t("key", default: "English text")
      #   I18n.translate("key", default: "English text")
      #
      #   # good
      #   I18n.t("key")
      #   t("key")
      #   I18n.translate("key")
      #
      class I18nNoDefault < Base
        extend AutoCorrector

        MSG = "Do not use default: parameter with I18n. " \
              "Strict I18n mode is enabled - all translations must exist in locale files. " \
              "Add the translation to config/locales/en_*.yml and nl_*.yml files."

        RESTRICT_ON_SEND = %i[t translate].freeze

        def_node_matcher :i18n_with_default?, <<~PATTERN
          (send
            {nil? (const nil? :I18n)}
            {:t :translate}
            _
            (hash <(pair (sym :default) _) ...>)
          )
        PATTERN

        def on_send(node)
          return unless i18n_with_default?(node)

          # Find the hash argument
          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return unless hash_arg

          # Find the default: pair
          default_pair = hash_arg.pairs.find do |pair|
            pair.key.sym_type? && pair.key.value == :default
          end
          return unless default_pair

          add_offense(default_pair, message: MSG) do |corrector|
            # Remove the default: parameter
            remove_default_parameter(corrector, hash_arg, default_pair)
          end
        end

        private

        def remove_default_parameter(corrector, hash_node, default_pair)
          # If this is the only pair in the hash, remove the entire hash argument
          if hash_node.pairs.size == 1
            # Find the comma before the hash argument if it exists
            hash_index = hash_node.parent.arguments.index(hash_node)
            if hash_index > 0
              # Remove the comma before the hash
              prev_arg = hash_node.parent.arguments[hash_index - 1]
              range_to_remove = prev_arg.source_range.end.join(hash_node.source_range.end)
              corrector.remove(range_to_remove)
            else
              corrector.remove(hash_node)
            end
          else
            # Remove just the default: pair
            # This is complex because we need to handle comma placement
            # For now, just remove the pair and any trailing comma
            pair_index = hash_node.pairs.index(default_pair)
            if pair_index < hash_node.pairs.size - 1
              # Not the last pair, remove up to the next pair
              next_pair = hash_node.pairs[pair_index + 1]
              range = default_pair.source_range.join(next_pair.source_range.begin)
              corrector.remove(range)
            else
              # Last pair, remove the comma before it if exists
              if pair_index > 0
                prev_pair = hash_node.pairs[pair_index - 1]
                range = prev_pair.source_range.end.join(default_pair.source_range.end)
                corrector.remove(range)
              else
                corrector.remove(default_pair)
              end
            end
          end
        end
      end
    end
  end
end
