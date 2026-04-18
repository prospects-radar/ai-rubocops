# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects Bootstrap utility classes applied to standardized design system
      # components. Reduces variants through composition: keep components simple,
      # wrap for complex styling.
      #
      # Use component parameters (color:, size:, variant:) where they exist.
      # For styling not covered by parameters, wrap the component in Box/FlexColumn.
      #
      # See: .claude/design-system-composition-pattern.md
      #
      # @example Bad (extra utilities on component)
      #   Paragraph(size: :sm, class: "fw-medium text-primary")
      #   Icon(name: "check", class: "text-success fs-5")
      #   Heading(level: 3, class: "small mb-3")
      #
      # @example Good (use parameters)
      #   Paragraph(size: :sm)  # Keep it simple
      #   Icon(name: "check", color: :success, size: :lg)
      #   Heading(level: 3, size: "12px")
      #
      # @example Good (wrap for complex styling)
      #   Box(class: "fw-medium text-primary") { Paragraph(size: :sm) { "text" } }
      #   Box(class: "text-decoration-line-through") { Icon(name: "check", color: :success) }
      #
      class NoExtraClassesOnStandardizedComponents < Base
        MSG = "Remove Bootstrap utilities from standardized components and use composition. " \
              "Use parameters (color:, size:, variant:) or wrap in Box/FlexColumn. " \
              "See: .claude/design-system-composition-pattern.md. " \
              "Detected classes: %<classes>s"

        # Components that should NOT have Bootstrap utility classes
        # They have semantic parameters for all styling concerns
        RESTRICTED_COMPONENTS = %w[
          Heading Paragraph Text Span Badge Button Input Select TextArea Icon
          Label FormGroup
        ].freeze

        # Bootstrap utility class patterns to detect
        # Grouped by category for clearer reporting
        UTILITY_PATTERNS = {
          text_utilities: %w[
            text- fw- fs- font- letter-spacing small lead word-wrap
          ],
          margin_padding: %w[
            m- mt- mb- ml- mr- mx- my- p- pt- pb- pl- pr- px- py-
          ],
          display_layout: %w[
            d- display- flex- align- justify- gap- float- position-
          ],
          sizing: %w[
            w- h- min- max- aspect-
          ],
          colors: %w[
            bg- border- shadow-
          ],
          borders: %w[
            border- rounded- outline-
          ]
        }.freeze

        def on_send(node)
          return unless restricted_component?(node)
          return unless has_class_parameter?(node)

          class_value = extract_class_value(node)
          return unless class_value

          detected_utilities = detect_utilities(class_value)
          return if detected_utilities.empty?

          add_offense(
            find_class_pair(node),
            message: format(MSG, classes: detected_utilities.join(", "))
          )
        end

        private

        def restricted_component?(node)
          component_name = node.method_name.to_s
          return false unless RESTRICTED_COMPONENTS.include?(component_name)

          # Allow extra classes on atoms and molecules - they're foundational building blocks
          # Only restrict classes on domain components
          file_path = processed_source.file_path
          file_path.include?("/atoms/") || file_path.include?("/molecules/") ? false : true
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

        def detect_utilities(class_string)
          classes = class_string.split(/\s+/)
          detected = []

          classes.each do |klass|
            UTILITY_PATTERNS.each do |_category, patterns|
              patterns.each do |pattern|
                if klass.start_with?(pattern) || EXACT_UTILITIES.include?(klass)
                  detected << klass
                  break
                end
              end
            end
          end

          detected.uniq
        end

        # Exact matches for utilities that don't follow prefix patterns
        EXACT_UTILITIES = %w[
          small lead sans serif d-inline d-block d-flex d-grid d-none
          align-items-center align-items-start align-items-end
          justify-content-start justify-content-center justify-content-end
          justify-content-between
          flex-wrap flex-nowrap flex-row flex-column flex-shrink flex-grow
          gap-1 gap-2 gap-3 gap-4 gap-5
          float-start float-end float-none
          position-static position-relative position-absolute position-fixed
          cursor-pointer cursor-default cursor-disabled
        ].freeze
      end
    end
  end
end
