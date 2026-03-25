# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Enforces that all AI agents inherit from ApplicationAgent or a valid RAAF base class.
      #
      # Similar to ServiceInheritance - ensures proper base class for AI components (DEC-016).
      #
      # @example
      #   # bad
      #   module Ai::Agents::Prospect
      #     class Discovery
      #       # Missing inheritance
      #     end
      #   end
      #
      #   # good
      #   module Ai::Agents::Prospect
      #     class Discovery < ApplicationAgent
      #       # Proper inheritance
      #     end
      #   end
      #
      #   # also good - inheriting from intermediate base classes
      #   module Ai::Agents::Company
      #     class DataGatherer < Ai::Agents::PerplexityFactualSearchAgent
      #       # PerplexityFactualSearchAgent inherits from ApplicationAgent
      #     end
      #   end
      #
      #   # also good - RAAF Pipeline for orchestration
      #   module Ai::Agents::Prospect
      #     class Enrichment < RAAF::Pipeline
      #       # Pipelines orchestrate multiple agents
      #     end
      #   end
      #
      class AgentInheritance < Base
        extend AutoCorrector

        MSG = "AI agents must inherit from ApplicationAgent (DEC-016). " \
              "This provides access to RAAF DSL and proper agent configuration."

        def on_class(node)
          return unless ai_agent_class?(node)
          return if inherits_from_valid_base?(node)

          add_offense(node.identifier, message: MSG) do |corrector|
            if node.parent_class.nil?
              # Class has no parent, add inheritance
              corrector.replace(node.loc.name, "#{node.identifier.source} < ApplicationAgent")
            else
              # Class has wrong parent, replace it
              corrector.replace(node.parent_class, "ApplicationAgent")
            end
          end
        end

        private

        def ai_agent_class?(node)
          file_path = processed_source.file_path

          # Only check files in the AI agents directory
          # This prevents conflicts with ServiceInheritance cop
          return false unless file_path.include?("app/ai/agents/")

          # Exclude known service-like classes that live in agents directory
          # but are not actually RAAF agents (they're plain Ruby service classes)
          # These classes explicitly document they are NOT RAAF agents
          !excluded_agent_paths.any? { |path| file_path.end_with?(path) }
        end

        def inherits_from_valid_base?(node)
          parent = node.parent_class
          return false unless parent

          parent_name = parent.source

          return true if valid_base_classes.include?(parent_name)
          return true if pipeline_classes.include?(parent_name)

          known_agent_base_classes.include?(parent_name)
        end

        def excluded_agent_paths
          cop_config.fetch("ExcludedAgentPaths", %w[
            app/ai/agents/linkedin/profile_discovery.rb
            app/ai/agents/phone/discovery.rb
            app/ai/agents/social/profile_discovery.rb
          ])
        end

        def valid_base_classes
          cop_config.fetch("ValidBaseClasses", %w[
            ApplicationAgent
            ::ApplicationAgent
            Ai::ApplicationAgent
            ::Ai::ApplicationAgent
            Ai::Agents::ApplicationAgent
            ::Ai::Agents::ApplicationAgent
            RAAF::Agent
            ::RAAF::Agent
          ])
        end

        def pipeline_classes
          cop_config.fetch("PipelineClasses", %w[
            RAAF::Pipeline
            ::RAAF::Pipeline
          ])
        end

        def known_agent_base_classes
          cop_config.fetch("KnownAgentBaseClasses", %w[
            PerplexityFactualSearchAgent
            Ai::Agents::PerplexityFactualSearchAgent
            ::Ai::Agents::PerplexityFactualSearchAgent
          ])
        end
      end
    end
  end
end
