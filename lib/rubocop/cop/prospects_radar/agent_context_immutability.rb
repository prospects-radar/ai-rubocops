# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Prevents agents from mutating shared context directly.
      #
      # Agents should return new data rather than modifying shared context hashes.
      # Mutating shared state makes agent pipelines unpredictable and hard to debug.
      #
      # @example
      #   # bad - mutating shared context
      #   def execute(context)
      #     context[:score] = calculate_score
      #     context[:analysis] = run_analysis
      #   end
      #
      #   # bad - mutating context via merge!
      #   def execute(context)
      #     context.merge!(score: 42)
      #   end
      #
      #   # good - returning new data
      #   def execute(context)
      #     {
      #       score: calculate_score,
      #       analysis: run_analysis
      #     }
      #   end
      #
      #   # good - using result builder
      #   def execute(context)
      #     success_result(score: calculate_score)
      #   end
      #
      class AgentContextImmutability < Base
        MSG = "Do not mutate shared agent context directly. " \
              "Return new data from the agent instead of modifying the context hash."

        MSG_MERGE = "Do not use `merge!` or `update` on agent context. " \
                    "Return new data instead."

        def on_def(node)
          return unless in_agent_file?
          return unless agent_execution_method?(node)

          context_param = find_context_param(node)
          return unless context_param

          check_context_mutations(node, context_param)
        end

        private

        def mutating_methods
          cop_config.fetch("MutatingMethods", %w[merge! update replace store]).map(&:to_sym)
        end

        def in_agent_file?
          file_path = processed_source.file_path
          file_path.include?("app/ai/agents/")
        end

        def agent_execution_method?(node)
          %i[execute process call run handle perform].include?(node.method_name)
        end

        def find_context_param(node)
          node.arguments.children.each do |arg|
            name = arg.name.to_s
            return name if %w[context ctx shared_context pipeline_context].include?(name)
          end

          nil
        end

        def check_context_mutations(node, context_param)
          node.each_descendant(:send) do |send_node|
            check_bracket_assignment(send_node, context_param)
            check_mutating_methods(send_node, context_param)
          end

          node.each_descendant(:op_asgn) do |op_asgn_node|
            check_op_assignment(op_asgn_node, context_param)
          end
        end

        def check_bracket_assignment(node, context_param)
          return unless node.method_name == :[]=

          receiver = node.receiver
          return unless receiver&.lvar_type?
          return unless receiver.children[0].to_s == context_param

          add_offense(node, message: MSG)
        end

        def check_mutating_methods(node, context_param)
          return unless mutating_methods.include?(node.method_name)

          receiver = node.receiver
          return unless receiver&.lvar_type?
          return unless receiver.children[0].to_s == context_param

          add_offense(node, message: MSG_MERGE)
        end

        def check_op_assignment(node, context_param)
          # Handles context[:key] ||= value
          return unless node.children[0]&.send_type?

          receiver_send = node.children[0]
          return unless receiver_send.method_name == :[]

          receiver = receiver_send.receiver
          return unless receiver&.lvar_type?
          return unless receiver.children[0].to_s == context_param

          add_offense(node, message: MSG)
        end
      end
    end
  end
end
