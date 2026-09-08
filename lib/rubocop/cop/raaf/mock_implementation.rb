# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Placeholder scoring must not ship as library code.
      #
      # Eleven of the twelve LLM evaluators answer with a `mock_*` or
      # `simulate_*` heuristic — counting shared words, measuring string length
      # — behind a `# TODO: Replace with actual RAAF LLM call`. Callers cannot
      # tell the difference from a real judgement: the result hash, the label
      # and the `evaluator_type :llm_judge` declaration are identical.
      # Meanwhile `LLMJudge::StatisticalJudge` and `RSpec::LLMJudge` both have
      # working judge plumbing that nothing routes to.
      #
      # `LLM::GEval` is the exception and the shape to copy: it calls a model
      # and drops to `mock_criteria_evaluation` only on a logged failure. A
      # fallback behind a real call is fine; a fallback that *is* the
      # implementation is not.
      #
      # Either call a judge, or raise `NotImplementedError` so an unfinished
      # evaluator fails loudly instead of returning a confident 0.83.
      #
      # @example
      #   # bad
      #   def mock_faithfulness_score(answer, context)
      #     0.6 + (grounded_ratio * 0.4)
      #   end
      #
      #   # good
      #   def judge_faithfulness(answer, context)
      #     judge.score(build_faithfulness_prompt(answer, context))
      #   end
      class MockImplementation < Base
        MSG = "`%<method>s` is placeholder scoring in library code; " \
              "call a judge or raise NotImplementedError."

        def on_def(node)
          return unless placeholder?(node.method_name)

          add_offense(node, message: format(MSG, method: node.method_name))
        end
        alias on_defs on_def

        private

        def placeholder?(method_name)
          method_name.to_s.match?(pattern)
        end

        def pattern
          @pattern ||= Regexp.new(cop_config.fetch("Pattern", '\A(mock|simulate|fake|dummy)_'))
        end
      end
    end
  end
end
