# frozen_string_literal: true

module RuboCop
  module Cop
    module Cucumber
      # Detects use of `sleep` in Cucumber step definitions.
      #
      # Sleep statements in tests are anti-patterns that make tests slow and flaky.
      # Instead, use Capybara's built-in waiting mechanisms that wait for specific
      # conditions rather than arbitrary time periods.
      #
      # @example Bad - Using sleep
      #   # bad
      #   When('I click the button') do
      #     click_button 'Submit'
      #     sleep 2  # Wait for page to load
      #   end
      #
      # @example Good - Using Capybara waiting
      #   # good
      #   When('I click the button') do
      #     click_button 'Submit'
      #     expect(page).to have_current_path(success_path, wait: 5)
      #   end
      #
      #   # good - wait for element
      #   When('I click the button') do
      #     click_button 'Submit'
      #     expect(page).to have_selector('.success-message', wait: 5)
      #   end
      #
      #   # good - wait for text
      #   When('I click the button') do
      #     click_button 'Submit'
      #     expect(page).to have_text('Success!', wait: 5)
      #   end
      #
      class NoSleepInCucumber < Base
        MSG = "Avoid using `sleep` in Cucumber steps. Use Capybara's waiting mechanisms instead: " \
              "`expect(page).to have_selector(..., wait: 5)`, " \
              "`expect(page).to have_current_path(..., wait: 5)`, or " \
              "`expect(page).to have_text(..., wait: 5)`"

        # Match: sleep(number) or sleep number
        def_node_matcher :sleep_call?, <<~PATTERN
          (send nil? :sleep ...)
        PATTERN

        def on_send(node)
          return unless sleep_call?(node)

          add_offense(node)
        end
      end
    end
  end
end
