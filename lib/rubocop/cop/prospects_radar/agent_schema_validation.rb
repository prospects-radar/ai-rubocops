# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Enforces that agents declaring a schema also validate their output against it.
      #
      # When an agent defines a schema (via def schema or schema method), the output
      # should be validated against that schema. Agents that declare a contract but
      # don't enforce it provide false confidence in data quality.
      #
      # @example
      #   # bad - schema declared but no validation
      #   class AnalysisAgent < ApplicationAgent
      #     def schema
      #       { type: "object", properties: { score: { type: "integer" } } }
      #     end
      #
      #     def process(result)
      #       result
      #     end
      #   end
      #
      #   # good - schema with validation
      #   class AnalysisAgent < ApplicationAgent
      #     def schema
      #       { type: "object", properties: { score: { type: "integer" } } }
      #     end
      #
      #     def process(result)
      #       validate_schema!(result)
      #       result
      #     end
      #   end
      #
      #   # good - using output_schema DSL (framework handles validation)
      #   class AnalysisAgent < ApplicationAgent
      #     output_schema AnalysisSchema
      #   end
      #
      class AgentSchemaValidation < Base
        MSG = "Agent declares a schema but does not validate output against it. " \
              "Use `validate_schema!`, `output_schema`, or `validate_output` to enforce the contract."

        def on_class(node)
          return unless in_agent_file?
          return unless has_schema_definition?(node)
          return if has_schema_validation?(node)
          return if has_output_schema_dsl?(node)

          add_offense(node.identifier, message: MSG)
        end

        private

        def in_agent_file?
          file_path = processed_source.file_path
          file_path.include?("app/ai/agents/")
        end

        def has_schema_definition?(node)
          node.each_descendant(:def).any? do |method_node|
            %i[schema output_schema response_schema].include?(method_node.method_name)
          end
        end

        def has_schema_validation?(node)
          validation_methods = %i[
            validate_schema! validate_schema validate_output validate_output!
            validate_response validate_response! schema_validate!
          ]

          node.each_descendant(:send).any? do |send_node|
            validation_methods.include?(send_node.method_name)
          end
        end

        def has_output_schema_dsl?(node)
          node.each_descendant(:send).any? do |send_node|
            send_node.method_name == :output_schema && send_node.receiver.nil?
          end
        end
      end
    end
  end
end
