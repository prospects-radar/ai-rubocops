# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Prefers RAAF.logger over Rails.logger in AI code
      #
      # @example
      #   # bad (in app/ai/)
      #   Rails.logger.info "Processing"
      #
      #   # good
      #   RAAF.logger.info "Processing"
      #
      class Logger < Base
        extend AutoCorrector

        MSG = "Use `RAAF.logger` instead of `Rails.logger` in AI code for RAAF-specific logging features"

        def_node_matcher :rails_logger?, <<~PATTERN
          (send (const nil? :Rails) :logger)
        PATTERN

        def on_send(node)
          return unless in_ai_directory?

          rails_logger?(node) do
            add_offense(node) do |corrector|
              corrector.replace(node.loc.expression, "RAAF.logger")
            end
          end
        end

        private

        def in_ai_directory?
          processed_source.path.include?("app/ai/")
        end
      end
    end
  end
end
