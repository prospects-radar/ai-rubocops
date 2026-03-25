# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Enforces that agents instantiate tools via `build_tool` instead of
      # calling `Tool.new` directly, ensuring scoped tool enforcement.
      #
      # When an agent declares `allowed_tools`, direct `Tool.new` calls
      # bypass the scope check. Using `build_tool(ToolClass)` ensures the
      # tool is validated against the agent's allowed list.
      #
      # @example
      #   # bad - bypasses tool scope enforcement
      #   class MyAgent < ApplicationAgent
      #     allowed_tools GoogleCustomSearchTool
      #
      #     def run
      #       tool = GoogleCustomSearchTool.new
      #       tool.call(query: "test")
      #     end
      #   end
      #
      #   # good - uses build_tool for scope enforcement
      #   class MyAgent < ApplicationAgent
      #     allowed_tools GoogleCustomSearchTool
      #
      #     def run
      #       tool = build_tool(GoogleCustomSearchTool)
      #       tool.call(query: "test")
      #     end
      #   end
      #
      class AgentToolScope < Base
        MSG = "Use `build_tool(%<tool>s)` instead of `%<tool>s.new` " \
              "to enforce scoped tool access in agents."

        def on_send(node)
          return unless node.method?(:new)
          return unless tool_instantiation?(node)
          return unless inside_agent_class?(node)

          tool_name = node.receiver.source
          add_offense(node, message: format(MSG, tool: tool_name))
        end

        private

        def tool_instantiation?(node)
          receiver = node.receiver
          return false unless receiver&.const_type?

          const_name = receiver.source
          const_name.end_with?("Tool")
        end

        def inside_agent_class?(node)
          node.each_ancestor(:class).any? do |class_node|
            parent = class_node.parent_class
            next false unless parent

            parent_name = parent.source
            parent_name.include?("ApplicationAgent") ||
              parent_name.include?("PerplexityFactualSearchAgent") ||
              parent_name.include?("RAAF::DSL::Agent")
          end
        end
      end
    end
  end
end
