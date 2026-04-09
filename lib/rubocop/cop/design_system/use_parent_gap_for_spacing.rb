# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces parent-controlled spacing pattern: all spacing between elements
      # comes from parent container's `gap:` parameter, not margin utilities on
      # individual components.
      #
      # This ensures:
      # - Consistent spacing across the entire design system
      # - Predictable layout flow (gap: :xs, :sm, :md, :lg, :xl)
      # - No ad-hoc margin utilities scattered throughout components
      # - Clear separation: parents control layout, components don't
      #
      # @example Bad (margin utilities on components)
      #   FlexRow(gap: :md) do
      #     Icon(name: "check", class: "mt-2px")         # Wrong: spacing on Icon
      #     Span(size: :sm, class: "ms-3") { text }      # Wrong: spacing on Span
      #   end
      #
      # @example Good (parent controls spacing)
      #   FlexRow(gap: :md, align: :center) do
      #     Icon(name: "check")                            # Clean: no margins
      #     Span(size: :sm) { text }                       # Clean: no margins
      #   end
      #
      # @example Good (Box/FlexRow/FlexColumn can have margins for exceptional layout)
      #   Box(class: "mt-4") do      # OK: Box is a layout container
      #     content_goes_here
      #   end
      #
      class UseParentGapForSpacing < Base
        MSG = "Use parent container's gap: parameter for spacing instead of " \
              "margin utilities. Components should not have mt-, mb-, ms-, me-, m- classes. " \
              "Set gap: :xs/:sm/:md/:lg/:xl on the parent FlexRow/FlexColumn. " \
              "Detected margin utilities: %<classes>s"

        # Components that should NEVER have margin utilities
        # (Layout containers Box/FlexRow/FlexColumn are exempt)
        RESTRICTED_COMPONENTS = %w[
          Heading Paragraph Text Span Badge Button Input Select TextArea Icon
          Label FormGroup ExternalLink Link
        ].freeze

        # Margin utility patterns that indicate violations
        MARGIN_PATTERNS = %w[
          mt- mb- ms- me- m-
          pt- pb- ps- pe- p-
        ].freeze

        def on_send(node)
          return unless restricted_component?(node)
          return unless has_class_parameter?(node)

          class_value = extract_class_value(node)
          return unless class_value

          margin_utilities = detect_margin_utilities(class_value)
          return if margin_utilities.empty?

          add_offense(
            node,
            message: format(MSG, classes: margin_utilities.join(", "))
          )
        end

        private

        def restricted_component?(node)
          component_name = node.method_name.to_s
          RESTRICTED_COMPONENTS.include?(component_name)
        end

        def has_class_parameter?(node)
          node.arguments.any? do |arg|
            arg.hash_type? && arg.pairs.any? do |pair|
              pair.key.sym_type? && pair.key.value == :class
            end
          end
        end

        def extract_class_value(node)
          class_pair = find_class_pair(node)
          return nil unless class_pair

          value_node = class_pair.value
          return value_node.value if value_node.str_type?
          return value_node.source if value_node.dstr_type?

          nil
        end

        def find_class_pair(node)
          return nil unless node.arguments.any?

          node.arguments.each do |arg|
            next unless arg.hash_type?

            arg.pairs.each do |pair|
              return pair if pair.key.sym_type? && pair.key.value == :class
            end
          end
          nil
        end

        def detect_margin_utilities(class_string)
          classes = class_string.split(/\s+/)
          detected = []

          classes.each do |klass|
            MARGIN_PATTERNS.each do |pattern|
              if klass.start_with?(pattern)
                detected << klass
                break
              end
            end
          end

          detected.uniq
        end
      end
    end
  end
end
