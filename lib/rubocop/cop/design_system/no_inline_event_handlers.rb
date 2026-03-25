# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Prevents inline event handlers in components (use Stimulus instead).
      #
      # Note: Phlex already blocks most of these, so this cop has limited utility.
      #
      # @example
      #   # bad (if it were possible)
      #   button(onclick: "doSomething()")
      #
      #   # good
      #   button(data: { controller: "button", action: "click->button#doSomething" })
      #
      class NoInlineEventHandlers < Base
        MSG = "Avoid inline event handlers. Use Stimulus controllers instead"

        INLINE_HANDLERS = %i[
          onclick
          onchange
          onsubmit
          onkeyup
          onkeydown
          onmousedown
          onmouseup
          onfocus
          onblur
        ].freeze

        def_node_matcher :inline_handler?, <<~PATTERN
          (pair (sym $INLINE_HANDLERS) ...)
        PATTERN

        def on_pair(node)
          return unless in_component_file?

          inline_handler?(node) do |_handler_name|
            add_offense(node)
          end
        end

        private

        def in_component_file?
          processed_source.path.include?("app/components/")
        end
      end
    end
  end
end
