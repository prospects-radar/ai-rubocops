# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Flags agents that call `.run` on other agents directly inside their
      # own `.run` method. Multi-agent orchestration should use
      # `RAAF::Pipeline` for traceability, testability, and auditability.
      #
      # @example
      #   # bad - inline agent orchestration
      #   class MyAgent < ApplicationAgent
      #     def run
      #       queries = BroadQueryFormulator.new(company: company).run
      #       # ... process queries ...
      #       super
      #     end
      #   end
      #
      #   # good - use a pipeline
      #   class MyPipeline < RAAF::Pipeline
      #     flow BroadQueryFormulator >> MyAnalyzer
      #   end
      #
      class RaafAgentNoInlineOrchestration < Base
        MSG = "Avoid calling `.run` on other agents inside an agent's `run` method. " \
              "Use `RAAF::Pipeline` for multi-agent orchestration."

        def on_send(node)
          return unless node.method_name == :run
          return unless node.arguments.empty?
          return unless inside_agent_run_method?(node)
          return if calling_super?(node)
          return unless receiver_is_agent?(node)

          add_offense(node)
        end

        private

        def inside_agent_run_method?(node)
          # Check we're inside a `def run` method inside an agent class
          in_run_method = node.each_ancestor(:def).any? { |m| m.method_name == :run }
          return false unless in_run_method

          node.each_ancestor(:class).any? do |class_node|
            parent = class_node.parent_class
            next false unless parent

            parent_name = parent.source
            parent_name.include?("ApplicationAgent") ||
              parent_name.include?("PerplexityFactualSearchAgent") ||
              parent_name.include?("RAAF::DSL::Agent")
          end
        end

        def calling_super?(node)
          node.type == :zsuper || (node.receiver.nil? && node.method_name == :run)
        end

        def receiver_is_agent?(node)
          receiver = node.receiver
          return false unless receiver

          # Direct constant call: SomeAgent.new(...).run
          if receiver.send_type? && receiver.method?(:new)
            const = receiver.receiver
            return false unless const&.const_type?

            const_name = const.source
            return const_name.end_with?("Agent", "Analyzer", "Scorer",
                                        "Classifier", "Detector", "Generator",
                                        "Finder", "Monitor", "Gatherer",
                                        "Discovery", "Formulator")
          end

          # Variable call: agent.run
          if receiver.lvar_type? || receiver.ivar_type?
            var_name = receiver.children[0].to_s
            return var_name.include?("agent") ||
                   var_name.end_with?("_formulator", "_analyzer", "_scorer",
                                      "_discovery", "_detector", "_monitor")
          end

          false
        end
      end
    end
  end
end
