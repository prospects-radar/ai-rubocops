# frozen_string_literal: true

module RuboCop
  module Cop
    module ProspectsRadar
      # Enforces frozen_string_literal: true at the top of all Ruby files.
      #
      # This is REQUIRED per AGENTS.md and ensures string immutability for better performance.
      #
      # @example
      #   # bad
      #   class MyClass
      #     # missing frozen_string_literal comment
      #   end
      #
      #   # good
      #   # frozen_string_literal: true
      #
      #   class MyClass
      #   end
      #
      class FrozenStringLiteral < Base
        extend AutoCorrector

        MSG = "Missing `# frozen_string_literal: true` at the top of the file. " \
              "This is REQUIRED per AGENTS.md guidelines."

        def on_new_investigation
          return if frozen_string_literal_comment_exists?

          # Use the first line of the file for the offense location
          range = source_range(processed_source.buffer, 1, 0)

          add_offense(range, message: MSG) do |corrector|
            corrector.insert_before(range, "# frozen_string_literal: true\n\n")
          end
        end

        private

        def frozen_string_literal_comment_exists?
          # Check if any of the comments contain frozen_string_literal
          processed_source.comments.any? do |comment|
            comment.text.match?(/\A#\s*frozen_string_literal:\s*(true|false)\z/)
          end
        end
      end
    end
  end
end
