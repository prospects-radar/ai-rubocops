# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Enforces the use of data-test-id attributes in Cucumber step definitions
      # instead of CSS selectors or text-based selectors for language independence.
      #
      # Using data-test-id attributes makes tests:
      # - Language independent (works in EN/NL/any locale)
      # - More maintainable (decoupled from UI text changes)
      # - More reliable (not affected by CSS class refactoring)
      # - Explicit about test intention
      #
      # @example Bad - CSS selector
      #   find('.submit-button').click
      #   find('button.btn-primary').click
      #   find('#login-form input[type="submit"]').click
      #
      # @example Bad - Text-based selector
      #   click_button 'Submit'
      #   click_link 'Sign In'
      #   fill_in 'Email address', with: 'user@example.com'
      #
      # @example Good - data-test-id
      #   find('[data-testid="submit-button"]').click
      #   find('[data-testid="login-submit"]').click
      #   find('[data-testid="email-input"]').fill_in(with: 'user@example.com')
      #
      # @example Good - tid helper (preferred in components)
      #   button(**tid("submit-button"))
      #
      class CucumberPreferTestId < Base
        MSG_CSS_SELECTOR = "Use data-test-id instead of CSS selectors for language-independent testing. " \
                          "Replace with find('[data-testid=\"...\"]')"
        MSG_TEXT_SELECTOR = "Use data-test-id instead of text-based selectors for language-independent testing. " \
                           "Text changes with locale, test-ids do not."
        MSG_CAPYBARA_METHOD = "Prefer data-test-id selectors over %<method>s with text. " \
                             "Use find('[data-testid=\"...\"]').click instead"

        # CSS selector patterns that should be replaced with test IDs
        CSS_SELECTOR_PATTERN = %r{
          (?:\.[\w-]+|                    # Class selectors: .btn, .submit-button
          \#[\w-]+|                       # ID selectors: #login-form
          \[[\w-]+[*^$]?=|                # Attribute selectors: [type="submit"], [class*="btn"]
          >\s*[\w-]+|                     # Child selectors: > button
          [\w-]+\s*[\[\.#])               # Combined selectors: button.primary, div#form
        }x

        # Methods that accept text/label arguments (language-dependent)
        TEXT_BASED_METHODS = %i[
          click_button
          click_link
          fill_in
          select
          choose
          check
          uncheck
          have_button
          have_link
          have_field
          have_checked_field
          have_unchecked_field
          have_select
        ].freeze

        # Whitelisted patterns that are acceptable
        WHITELIST_PATTERNS = [
          /data-testid/,                  # Already using test IDs
          /\[data-testid/,                # data-testid selector
          /\[role=/,                      # ARIA roles (accessibility)
          /\[aria-/,                      # ARIA attributes (accessibility)
          /\[data-[a-z-]+\]/,             # Other data attributes (data-filter, data-controller, etc.)
          /submit.*type.*submit/i,        # Generic submit button fallback
          /button\[type="submit"\]/,      # Generic submit selector
          /I18n\.t\(/,                    # I18n translations (acceptable in some contexts)
          /rescue/,                       # Rescue blocks (fallback logic)
          /\.ancestor\(/,                 # Traversing DOM (often necessary)
          /\.find\s*\(/,                  # Chained finds (complex queries)
          /\[.*\[.*\]\]/,                 # Rails form fields: field[name], company[website]
          /scroll_to/,                    # Scrolling actions
          /visible:\s*:all/,              # Visibility checks
          /match:\s*:first/               # Match options
        ].freeze

        def on_send(node)
          return unless in_step_definition_file?
          return if whitelisted_context?(node)

          check_for_css_selector(node)
          check_for_text_based_capybara(node)
        end

        private

        def in_step_definition_file?
          path = processed_source.file_path
          path.include?("features/step_definitions/") &&
            !path.include?("accessibility_steps.rb") # Accessibility tests need ARIA/semantic selectors
        end

        def whitelisted_context?(node)
          source_line = node.source
          WHITELIST_PATTERNS.any? { |pattern| source_line.match?(pattern) }
        end

        def check_for_css_selector(node)
          return unless node.method_name == :find

          # Check if first argument is a string (the selector)
          return unless node.arguments.first&.str_type?

          selector = node.arguments.first.value

          # Skip if already using data-testid
          return if selector.include?("data-testid")

          # Check for CSS selectors
          if selector.match?(CSS_SELECTOR_PATTERN)
            add_offense(node, message: MSG_CSS_SELECTOR)
          end
        end

        def check_for_text_based_capybara(node)
          return unless TEXT_BASED_METHODS.include?(node.method_name)

          # These methods typically take text as first argument
          first_arg = node.arguments.first
          return unless first_arg

          # If it's a string literal (not a variable), it's likely text-based
          if first_arg.str_type?
            text_value = first_arg.value

            # Skip certain acceptable patterns
            return if text_value.match?(/login[-_]email|login[-_]password/i) # Test IDs passed as strings
            return if text_value.empty? # Empty strings (testing validation)
            return if text_value.match?(/\[.*\]/) # Rails form fields: company[name]
            return if text_value.match?(/^[a-z_]+$/) && text_value.length < 20 # Short snake_case IDs

            add_offense(
              node,
              message: format(MSG_CAPYBARA_METHOD, method: node.method_name)
            )
          end
        end
      end
    end
  end
end
