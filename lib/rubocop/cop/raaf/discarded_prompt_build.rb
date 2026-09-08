# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # A built prompt whose return value is thrown away.
      #
      # Seven of the LLM evaluators call `build_*_prompt(...)` as a bare
      # statement and then return a word-overlap heuristic from a `mock_*`
      # method, so the prompt is constructed and dropped on every call. The
      # evaluator reads as an LLM judge — it declares `evaluator_type
      # :llm_judge` and is priced as one — while never reaching a model.
      #
      # Pass the prompt to a judge, or delete the builder.
      #
      # @example
      #   # bad
      #   def llm_judge_faithfulness(answer:, context:)
      #     build_faithfulness_prompt(answer, context)
      #     mock_faithfulness_score(answer, context)
      #   end
      #
      #   # good
      #   def llm_judge_faithfulness(answer:, context:)
      #     prompt = build_faithfulness_prompt(answer, context)
      #     judge.call(prompt)
      #   end
      class DiscardedPromptBuild < Base
        MSG = "The prompt built by `%<method>s` is discarded. Send it to a judge or delete the builder."

        def on_send(node)
          return unless node.receiver.nil?
          return unless builder?(node.method_name)
          return if node.value_used?

          add_offense(node, message: format(MSG, method: node.method_name))
        end

        private

        def builder?(method_name)
          method_name.to_s.match?(pattern)
        end

        def pattern
          @pattern ||= Regexp.new(cop_config.fetch("Pattern", '\Abuild_\w*prompt\z'))
        end
      end
    end
  end
end
