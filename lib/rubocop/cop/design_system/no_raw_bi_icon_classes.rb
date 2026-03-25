# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw Bootstrap Icon classes (bi bi-*) used outside the Icon atom.
      # Use Icon(name: "icon-name") instead.
      #
      # @example Bad
      #   i(class: "bi bi-chevron-right")
      #   div(class: "d-flex bi bi-arrow-left gap-2")
      #
      # @example Good
      #   Icon(name: "chevron-right")
      #   Icon(name: "arrow-left", size: :sm)
      class NoRawBiIconClasses < Base
        MSG = 'Use `Icon(name: "icon-name")` instead of raw Bootstrap Icon ' \
              "classes (`bi bi-*`). Raw icon classes bypass the GlassMorph design system."

        BI_ICON_PATTERN = /\bbi\s+bi-\w[\w-]*/.freeze

        def_node_matcher :class_string?, <<~PATTERN
          (pair (sym {:class}) (str $_))
        PATTERN

        def on_pair(node)
          class_string?(node) do |class_value|
            add_offense(node) if class_value.match?(BI_ICON_PATTERN)
          end
        end
      end
    end
  end
end
