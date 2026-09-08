# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Evaluators should inherit the shared base class rather than including
      # the bare interface module.
      #
      # `RAAF::Eval::DSL::Evaluator` only declares the contract: `evaluate`,
      # `calculate_label` and an unused `validate_result!`. Everything an
      # evaluator actually repeats — resolving the three-tier thresholds,
      # validating them, and building the result hash with its threshold
      # metadata and `"[LABEL] Name: NN%"` message — lives in
      # `Evaluators::LLM::BaseEvaluator`. Including the module directly means
      # hand-rolling all three, which is how the built-in set acquired three
      # different default threshold pairs and two incompatible label types.
      #
      # @example
      #   # bad
      #   class Latency
      #     include RAAF::Eval::DSL::Evaluator
      #   end
      #
      #   # good
      #   class Latency < BaseEvaluator
      #   end
      class EvaluatorBaseClass < Base
        MSG = "Inherit from `%<base>s` instead of including `%<mod>s` directly; " \
              "the base class already resolves thresholds and builds results."

        # @!method evaluator_include(node)
        def_node_search :evaluator_include, <<~PATTERN
          (send nil? :include $(const ...))
        PATTERN

        def on_class(node)
          return if node.parent_class

          evaluator_include(node) do |const|
            next unless interface_module?(const)

            add_offense(
              node.identifier,
              message: format(MSG, base: base_class, mod: const.source)
            )
            break
          end
        end

        private

        def interface_module?(const)
          const.source.end_with?(interface_module)
        end

        def interface_module
          cop_config.fetch("InterfaceModule", "DSL::Evaluator")
        end

        def base_class
          cop_config.fetch("BaseClass", "RAAF::Eval::Evaluators::Base")
        end
      end
    end
  end
end
