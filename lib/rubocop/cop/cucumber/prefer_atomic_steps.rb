# frozen_string_literal: true

module RuboCop
  module Cop
    module Cucumber
      # Prevents hard-coded Capybara interactions in organism/molecule steps.
      # These steps should compose atomic/molecule steps instead.
      #
      # @example
      #   # bad - in organisms/authentication.rb
      #   When('I log out') do
      #     find('[data-testid="sidebar-user-toggle"]').click
      #     find('[data-testid="user-menu-sign-out"]').click
      #   end
      #
      #   # good - compose atomic steps
      #   When('I log out') do
      #     step 'I click "sidebar-user-toggle"'
      #     step 'I click "user-menu-sign-out"'
      #   end
      #
      #   # bad - direct Capybara in molecules/form_fields.rb
      #   When('I fill in company name {string}') do |name|
      #     fill_in 'customer_company[name]', with: name
      #   end
      #
      #   # good - use atomic step
      #   When('I fill in company name {string}') do |name|
      #     step "I fill in \"customer_company[name]\" with \"#{name}\""
      #   end
      #
      #   # allowed - in atoms/clicks.rb (atomic layer)
      #   When('I click {string}') do |element_identifier|
      #     find_element_smart(element_identifier).click
      #   end
      #
      class PreferAtomicSteps < Base
        MSG = "Use atomic/molecule step composition (step '...') instead of hard-coded Capybara. " \
              "Only atoms/ and universal/ directories can use Capybara directly."

        # Capybara interaction methods that should be wrapped in atomic steps
        CAPYBARA_INTERACTION_METHODS = %i[
          click_button click_link click_on click
          fill_in select choose
          check uncheck
          attach_file
          find find_field find_button find_link
          within
          accept_alert dismiss_confirm accept_confirm
          execute_script evaluate_script
          send_keys
        ].freeze

        # Helper methods that are allowed (these are internal test helpers)
        ALLOWED_HELPER_METHODS = %i[
          step # Delegating to other steps (GOOD)
          with_tenant # Tenant context
          current_account # Test helper
          current_user # Test helper
          create # FactoryBot
          build # FactoryBot
          create_list # FactoryBot
          build_list # FactoryBot
          table # Cucumber table helper
          visit # Page visit - atomic enough
          current_path # Path checking
          expect # RSpec expectation
          have_css have_content have_text have_selector # RSpec matchers
          have_link have_button have_field
          be be_present be_nil # RSpec matchers
          eq # RSpec matcher
          all # Capybara - query only (non-interactive)
          has_css? has_content? has_text? has_selector? # Query methods (non-interactive)
          has_link? has_button? has_field?
        ].freeze

        # Custom helper methods defined in Cucumber support files
        CUSTOM_HELPER_PATTERNS = %w[
          _test_id
          find_field_element
          find_element_smart
          find_textarea_element
          current_page_context
          sign_in_
          fill_in_or_select_
          select_test_id
        ].freeze

        # Match Capybara interaction methods (both receiver and nil receiver)
        def_node_matcher :capybara_interaction?, <<~PATTERN
          (send {nil? _} $CAPYBARA_INTERACTION_METHODS ...)
        PATTERN

        # Match find() calls that are chained with interaction methods
        def_node_matcher :find_call?, <<~PATTERN
          (send nil? {:find :find_field :find_button :find_link} ...)
        PATTERN

        # Match chained interaction on find result (e.g., find(...).click)
        def_node_matcher :chained_interaction?, <<~PATTERN
          (send (send nil? {:find :find_field :find_button :find_link} ...) $CAPYBARA_INTERACTION_METHODS ...)
        PATTERN

        def on_send(node)
          return unless in_organism_or_molecule_file?
          return if in_allowed_helper?
          return if calling_custom_helper?(node)
          return if inside_step_delegation?(node)

          # Check for direct Capybara interaction calls
          capybara_interaction?(node) do |method_name|
            add_offense(node, message: format(MSG, method: method_name))
          end

          # Check for chained interactions like find(...).click
          chained_interaction?(node) do |method_name|
            add_offense(node, message: format(MSG, method: method_name))
          end

          # Check for find() calls themselves (even without chaining)
          if find_call?(node) && !inside_custom_helper_definition?(node)
            add_offense(node, message: "Use atomic/molecule step composition (step '...') instead of find(). " \
                                       "Only atoms/ and universal/ directories can use Capybara directly.")
          end
        end

        private

        def in_organism_or_molecule_file?
          path = processed_source.path
          return false unless path.include?("features/") && path.include?("step_definitions/")

          # Only check organism and molecule layers
          path.include?("/organisms/") || path.include?("/molecules/")
        end

        def in_allowed_helper?
          # Allow if we're inside a helper method definition (not inside a step block)
          # Helper methods are defined outside of When/Given/Then blocks
          path = processed_source.path
          # Check if we're in features/support/ (all helpers allowed there)
          path.include?("features/support/")
        end

        def calling_custom_helper?(node)
          # Check if the method call is to a custom helper
          method_name = node.method_name.to_s
          CUSTOM_HELPER_PATTERNS.any? { |pattern| method_name.include?(pattern) }
        end

        def inside_step_delegation?(node)
          # Check if we're inside a step '...' call (which is the GOOD pattern)
          # We want to allow Capybara calls that happen inside helper methods
          # called FROM atomic steps

          # Look for step(...) calls in the ancestor chain
          # The structure is: (send nil? :step (str "..."))
          node.each_ancestor.any? do |ancestor|
            # Check if this is a send node with method_name :step
            ancestor.send_type? && ancestor.method_name == :step
          end
        end

        def inside_custom_helper_definition?(node)
          # Check if we're inside a custom helper method definition
          # Helper methods are allowed to use Capybara
          node.each_ancestor(:def, :defs).any? do |ancestor|
            method_name = ancestor.method_name.to_s
            CUSTOM_HELPER_PATTERNS.any? { |pattern| method_name.include?(pattern) } ||
              ALLOWED_HELPER_METHODS.include?(ancestor.method_name)
          end
        end
      end
    end
  end
end
