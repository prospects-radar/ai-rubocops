# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Every evaluator must declare `evaluator_name`.
      #
      # `EvaluatorRegistry#validate_evaluator_class!` refuses to register a
      # class whose `evaluator_name` does not match the registration key, and
      # `nil` never matches. An evaluator without the declaration cannot be
      # reached through the DSL, through `EvaluatorDiscovery`, or from a
      # continuous-evaluation policy — it is dead weight that still reads as
      # shipped. `Evaluators::LLM::TaskCompletion` and `ToolCorrectness` are
      # 600 lines in exactly that state.
      #
      # Declare `evaluator_type` too when the evaluator is anything other than
      # rule_based: `EvaluatorDefinition#evaluated_checks` otherwise reports it
      # as free, and llm_judge checks are the ones that cost money.
      #
      # @example
      #   # bad
      #   class TaskCompletion < BaseEvaluator
      #     DEFAULT_GOOD_THRESHOLD = 0.85
      #   end
      #
      #   # good
      #   class TaskCompletion < BaseEvaluator
      #     evaluator_name :task_completion
      #     evaluator_type :llm_judge
      #   end
      class EvaluatorName < Base
        MSG = "Declare `evaluator_name`; the registry cannot register this evaluator without it."

        # @!method declares_evaluator_name?(node)
        def_node_search :declares_evaluator_name?, <<~PATTERN
          (send nil? :evaluator_name ...)
        PATTERN

        # @!method evaluator_include?(node)
        def_node_search :evaluator_include?, <<~PATTERN
          (send nil? :include (const ... :Evaluator))
        PATTERN

        def on_class(node)
          return unless evaluator?(node)
          return if allowed?(node)
          return if declares_evaluator_name?(node)

          add_offense(node.identifier)
        end

        private

        def evaluator?(node)
          inherits_base?(node) || evaluator_include?(node)
        end

        def inherits_base?(node)
          superclass = node.parent_class
          return false unless superclass&.const_type?

          superclass.source.end_with?(*base_classes)
        end

        def allowed?(node)
          allowed_names.include?(node.identifier.short_name.to_s)
        end

        def base_classes
          Array(cop_config.fetch("BaseClasses", %w[BaseEvaluator Evaluators::Base]))
        end

        def allowed_names
          Array(cop_config.fetch("AllowedNames", %w[BaseEvaluator Base]))
        end
      end
    end
  end
end
