# frozen_string_literal: true

module RuboCop
  module Cop
    module Cucumber
      # Enforces consistent wait timeout constants instead of magic numbers
      #
      # @example
      #   # bad
      #   Capybara.using_wait_time(10) do
      #     # ...
      #   end
      #
      #   # good
      #   Capybara.using_wait_time(WAIT_TIMEOUT) do
      #     # ...
      #   end
      #
      class ConsistentWaitTimeout < Base
        extend AutoCorrector

        MSG = "Use `WAIT_TIMEOUT` constant instead of magic number for Capybara wait times"

        def_node_matcher :using_wait_time_with_number?, <<~PATTERN
          (send (const nil? :Capybara) :using_wait_time (int $_))
        PATTERN

        def on_send(node)
          return unless in_cucumber_file?

          using_wait_time_with_number?(node) do |timeout_value|
            add_offense(node.first_argument) do |corrector|
              corrector.replace(node.first_argument.loc.expression, "WAIT_TIMEOUT")
            end
          end
        end

        private

        def in_cucumber_file?
          path = processed_source.path
          path.include?("features/") && (path.include?("step_definitions/") || path.include?("support/"))
        end
      end
    end
  end
end
