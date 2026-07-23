# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Enforces that per-agent `model`, `max_turns`, and `max_tokens` live in
      # config/ai_agents.yml (read by RAAF::DSL::Config), not inline in the agent
      # class. Keeping them in one YAML file makes every model/turn budget tunable
      # in a single place, and lets the boot guard verify every agent is configured
      # (no silent fall-back to gpt-4o).
      #
      # `temperature`, `provider`, `reasoning_effort`, `search_*`, tools and schema
      # stay in the class — they have no YAML path — so this cop does not touch them.
      #
      # Base classes (which carry framework defaults and, for Perplexity, derive the
      # model from `search_depth`) are excluded via `.rubocop.yml`.
      #
      # @example
      #   # bad
      #   class Scoring < Ai::Agents::ApplicationAgent
      #     agent_name "ProspectScoringAgent"
      #     model "gemini-2.5-flash"
      #     max_turns 1
      #   end
      #
      #   # good  — config/ai_agents.yml:
      #   #   prospect_scoring_agent:
      #   #     model: "gemini-2.5-flash"
      #   #     max_turns: 1
      #   class Scoring < Ai::Agents::ApplicationAgent
      #     agent_name "ProspectScoringAgent"
      #     temperature 0.0
      #   end
      #
      class AgentConfigInYaml < Base
        MSG = "Set `%<setting>s` in config/ai_agents.yml, not in the agent class " \
              "(single source of truth; the boot guard enforces coverage)."

        RESTRICT_ON_SEND = %i[model max_turns max_tokens].freeze

        def on_send(node)
          # Only the DSL setter form: a bare call with an argument (`model "x"`).
          # Getters (`model`) and receiver calls (`agent.model`) are legitimate.
          return if node.receiver
          return if node.arguments.empty?

          add_offense(node, message: format(MSG, setting: node.method_name))
        end
      end
    end
  end
end
