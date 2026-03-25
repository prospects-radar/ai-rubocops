# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Ensures AI prompts include language_output_instructions for I18n
      #
      # @example
      #   # bad
      #   def system
      #     "Analyze the company data"
      #   end
      #
      #   # good
      #   def system
      #     "Analyze the company data. #{language_output_instructions}"
      #   end
      #
      class PromptLanguageInstructions < Base
        MSG = "AI prompts should include `\#{language_output_instructions}` for I18n support"

        def_node_matcher :prompt_class?, <<~PATTERN
          (class
            (const ... _)
            (const (const (const nil? :RAAF) :DSL) :Prompts)
            ...
          )
        PATTERN

        def_node_matcher :system_or_user_method?, <<~PATTERN
          (def {:system :user} ...)
        PATTERN

        def_node_search :has_language_instructions?, <<~PATTERN
          (send nil? :language_output_instructions)
        PATTERN

        def on_class(node)
          return unless in_prompts_file?
          return unless prompt_class?(node)

          node.each_descendant(:def) do |def_node|
            next unless system_or_user_method?(def_node)
            next if has_language_instructions?(def_node)

            add_offense(def_node)
          end
        end

        private

        def in_prompts_file?
          path = processed_source.path
          path.include?("app/ai/") && path.include?("prompts/")
        end
      end
    end
  end
end
