# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Suggests using shared contexts for duplicated setup code
      #
      # This cop only provides suggestions - cannot automatically detect
      # what should be extracted.
      #
      # @example
      #   # Disabled by default - requires cross-file analysis
      #   # Enable manually to find duplication candidates
      #
      class PreferSharedContext < Base
        MSG = "Consider extracting duplicated setup to a shared context in spec/support/shared_contexts/"

        # This cop is intentionally basic - it detects patterns that MIGHT
        # benefit from shared contexts, but requires manual review
        def_node_matcher :complex_before_block?, <<~PATTERN
          (block
            (send nil? :before ...)
            _
            (begin
              $..._more_than_5
            )
          )
        PATTERN

        def on_block(node)
          return unless in_spec_file?
          return unless node.send_node.method_name == :before

          # Only flag before blocks with 5+ lines
          body = node.body
          return unless body && body.begin_type?
          return unless body.children.count >= 5

          add_offense(node)
        end

        private

        def in_spec_file?
          processed_source.path.include?("spec/") &&
            processed_source.path.end_with?("_spec.rb")
        end
      end
    end
  end
end
