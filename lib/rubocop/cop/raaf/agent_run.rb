# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Enforces .run for RAAF agents, not .call (DEC-016, DEC-018, DEC-019, DEC-020).
      #
      # RAAF agents use .run method for execution, not the standard Ruby .call convention.
      # Note: RAAF tools correctly use .call, this cop only checks agents.
      #
      # @example
      #   # bad
      #   agent = Ai::Agents::Prospect::Discovery.new(product: product)
      #   result = agent.call  # Wrong method
      #
      #   # good
      #   agent = Ai::Agents::Prospect::Discovery.new(product: product)
      #   result = agent.run  # Correct RAAF pattern
      #
      #   # good - tools use .call
      #   tool = SomeTool.new
      #   result = tool.call  # This is correct for tools
      #
      class AgentRun < Base
        extend AutoCorrector

        MSG = "RAAF agents must use .run, not .call (DEC-016). " \
              "Change to .run for proper RAAF execution."

        RESTRICT_ON_SEND = %i[call].freeze

        def on_send(node)
          receiver = node.receiver
          return unless receiver
          return unless agent_call?(receiver)

          add_offense(node.loc.selector, message: MSG) do |corrector|
            corrector.replace(node.loc.selector, "run")
          end
        end

        private

        def agent_call?(receiver)
          # Check if receiver is an agent variable or constant
          if receiver.const_type?
            agent_constant?(receiver)
          elsif receiver.lvar_type? || receiver.ivar_type?
            # For variables, check if they were assigned from an agent
            agent_variable?(receiver)
          elsif receiver.send_type? && receiver.method?(:new)
            # Direct call on .new: Agent.new(...).call
            agent_constant?(receiver.receiver)
          else
            false
          end
        end

        def agent_constant?(node)
          return false unless node

          const_name = const_name_for(node)
          return false unless const_name

          # Check if it's in the AI agents namespace
          return true if const_name.start_with?("Ai::Agents::")
          return true if const_name.start_with?("::Ai::Agents::")

          # Check if class name ends with Agent
          return true if const_name.end_with?("Agent")

          # Check common agent class patterns
          agent_patterns = %w[
            Discovery
            Analyzer
            Scorer
            Classifier
            Detector
            Generator
            Finder
            Monitor
            Gatherer
          ]

          agent_patterns.any? { |pattern| const_name.end_with?(pattern) }
        end

        def const_name_for(node)
          return nil unless node.const_type?

          parts = []
          current = node

          while current.const_type?
            if current.children[1]
              parts.unshift(current.children[1].to_s)
            end

            current = current.children[0]
            break unless current
          end

          parts.join("::")
        end

        def agent_variable?(node)
          # This is complex - would need to track variable assignments
          # For now, check if variable name suggests it's an agent
          var_name = node.children[0].to_s

          var_name.include?("agent") ||
            var_name.include?("pipeline") ||
            var_name.end_with?("_agent", "_pipeline")
        end
      end
    end
  end
end
