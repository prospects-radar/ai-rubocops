# frozen_string_literal: true

module RuboCop
  module Cop
    module Cucumber
      # Prefers expect().to have_css over if page.has_css?
      #
      # @example
      #   # bad
      #   if page.has_css?('.button')
      #     # ...
      #   end
      #
      #   # good
      #   expect(page).to have_css('.button')
      #
      class PreferHaveOverHasCss < Base
        MSG = "Use `expect(page).to have_css` instead of `page.has_css?` for better error messages"

        HAS_METHODS = %i[has_css? has_content? has_text? has_selector? has_link? has_button?].freeze

        def_node_matcher :has_method_call?, <<~PATTERN
          (send (send nil? :page) $HAS_METHODS ...)
        PATTERN

        def on_send(node)
          return unless in_cucumber_file?

          has_method_call?(node) do |method_name|
            # Only flag if used in conditional (if/unless)
            return unless in_conditional?(node)

            add_offense(node)
          end
        end

        private

        def in_cucumber_file?
          path = processed_source.path
          path.include?("features/") && path.include?("step_definitions/")
        end

        def in_conditional?(node)
          node.each_ancestor(:if, :unless).any?
        end
      end
    end
  end
end
