# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Evaluator labels must be the strings "good", "average" and "bad".
      #
      # `RAAF::Eval::DSL::EvaluationResult` sorts field results by comparing
      # `result[:label]` against string literals, and
      # `DSL::Evaluator#validate_result!` only accepts `%w[good average bad]`.
      # A symbol label therefore lands in no bucket at all: `failed_fields`
      # stays empty while `passed?` returns false, so the span reports a
      # failure that names no field.
      #
      # The same mismatch bites in the other direction when a label produced by
      # `calculate_label` (a String) is compared against a symbol —
      # `label == :good` is then always false and the message picks the wrong
      # branch every time.
      #
      # @example
      #   # bad
      #   { label: :good, score: 1.0 }
      #
      #   # bad
      #   message: "#{label == :good ? "fine" : "broken"}"
      #
      #   # bad
      #   def calculate_label_from_discrete_thresholds(...)
      #     :bad
      #   end
      #
      #   # good
      #   { label: "good", score: 1.0 }
      class EvaluatorLabelString < Base
        extend AutoCorrector

        MSG = "Use the string %<replacement>s for an evaluator label; " \
              "EvaluationResult and validate_result! only recognise strings."

        LABELS = %i[good average bad].freeze
        COMPARISONS = %i[== != eql? equal?].freeze

        def on_sym(node)
          return unless LABELS.include?(node.value)
          return unless label_position?(node)

          replacement = "\"#{node.value}\""

          add_offense(node, message: format(MSG, replacement: replacement)) do |corrector|
            corrector.replace(node, replacement)
          end
        end

        private

        # These words are also the keys `build_result` writes into its
        # `thresholds` hash, so most occurrences are lookups and assertions
        # rather than labels. Report only where a label can actually be:
        # assigned to `label:`, compared, matched, or returned.
        def label_position?(node)
          parent = node.parent
          return true if parent.nil?

          case parent.type
          when :pair then label_value?(parent, node)
          when :return, :when, :def, :defs, :begin, :kwbegin, :if then true
          when :send then COMPARISONS.include?(parent.method_name)
          else false
          end
        end

        def label_value?(pair, node)
          pair.value.equal?(node) && pair.key.sym_type? && pair.key.value == :label
        end
      end
    end
  end
end
