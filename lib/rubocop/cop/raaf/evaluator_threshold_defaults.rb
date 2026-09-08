# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Do not re-declare threshold defaults inside `evaluate`.
      #
      # `Evaluators::LLM::BaseEvaluator#resolve_thresholds` already implements
      # the three-tier precedence (call-time option, instance default, class
      # constant) and validates that good > average and both sit in 0.0..1.0.
      # Every evaluator that writes `options[:good_threshold] || 0.8` opts out
      # of that validation and picks its own default, which is why the built-in
      # set currently ships three different pairs (0.8/0.6, 0.85/0.7, 0.9/0.7)
      # for the same concept.
      #
      # @example
      #   # bad
      #   good_threshold = options[:good_threshold] || 0.8
      #   average_threshold = options[:average_threshold] || 0.6
      #
      #   # bad
      #   threshold_good = options[:threshold_good] || options[:good_threshold] || 0.85
      #
      #   # good
      #   DEFAULT_GOOD_THRESHOLD = 0.80
      #   DEFAULT_AVERAGE_THRESHOLD = 0.60
      #
      #   def evaluate(field_context, **options)
      #     good_threshold, average_threshold = resolve_thresholds(options)
      #   end
      class EvaluatorThresholdDefaults < Base
        MSG = "Resolve thresholds with `resolve_thresholds(options)` and class-level " \
              "DEFAULT_*_THRESHOLD constants instead of defaulting inline."

        THRESHOLD_KEYS = %i[
          good_threshold average_threshold
          threshold_good threshold_average
        ].freeze

        def on_or(node)
          # `a || b || c` nests to the left; only report the whole expression.
          return if node.parent&.or_type?
          return unless numeric?(final_fallback(node))
          return unless node.each_descendant(:send).any? { |send| threshold_lookup?(send) }

          add_offense(node)
        end

        private

        def final_fallback(node)
          node.rhs
        end

        # `options[:good_threshold]`, whatever the receiver is called.
        def threshold_lookup?(node)
          return false unless node.method?(:[])

          key = node.first_argument
          key&.sym_type? && THRESHOLD_KEYS.include?(key.value)
        end

        def numeric?(node)
          node && %i[int float].include?(node.type)
        end
      end
    end
  end
end
