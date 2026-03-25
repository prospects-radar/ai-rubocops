# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Blocks new Tailwind CSS class usage in GlassMorph components and views.
      #
      # Tailwind is deprecated. All new views must use Bootstrap 5 utility classes.
      # GlassMorph components are Bootstrap-based; mixing Tailwind classes breaks consistency.
      #
      # Common Tailwind → Bootstrap mappings:
      #   flex items-center       → d-flex align-items-center (or use FlexRow component)
      #   text-sm                 → small / fs-6
      #   font-medium             → fw-medium
      #   text-gray-500           → text-muted
      #   bg-gray-50              → bg-light
      #   rounded-lg              → rounded
      #   mt-6                    → mt-4
      #   grid grid-cols-*        → row + col-*
      #
      # @example
      #   # bad - Tailwind classes in GlassMorph view
      #   div(class: "flex items-center gap-3 text-gray-500")
      #
      #   # good - Bootstrap classes
      #   FlexRow(gap: :sm, align: :center) { ... }
      #   div(class: "d-flex align-items-center gap-3 text-muted")
      #
      class NoNewTailwindUsage < Base
        MSG = "Tailwind CSS classes detected in GlassMorph code. Use Bootstrap 5 classes instead. " \
              "See docs/plans/2026-03-04-ui-consistency-analysis.md for mapping."

        # Common Tailwind patterns that don't exist in Bootstrap
        TAILWIND_PATTERNS = [
          /(?<!align-)items-center\b/,   # Tailwind: items-center; Bootstrap false positive: align-items-center
          /\bjustify-between\b/,
          /\bjustify-center\b/,
          /\btext-gray-\d+\b/,
          /\bbg-gray-\d+\b/,
          /\btext-green-\d+\b/,
          /\bbg-green-\d+\b/,
          /\btext-blue-\d+\b/,
          /\bbg-blue-\d+\b/,
          /\btext-red-\d+\b/,
          /\bbg-red-\d+\b/,
          /\btext-amber-\d+\b/,
          /\bbg-amber-\d+\b/,
          /\btext-purple-\d+\b/,
          /\bbg-purple-\d+\b/,
          /\btext-indigo-\d+\b/,
          /\brounded-full\b/,
          /\brounded-lg\b/,
          /\btracking-wider\b/,
          /\bwhitespace-nowrap\b/,
          /\bline-clamp-\d+\b/,
          /(?<!text-)truncate\b/,        # Tailwind: truncate; Bootstrap false positive: text-truncate
          /\bgrid-cols-\d+\b/,
          /\bmd:grid-cols-\d+\b/,
          /\blg:col-span-\d+\b/,
          /\bdivide-y\b/,
          /\bdivide-gray-\d+\b/,
          /\bspace-y-\d+\b/,
          /\bspace-x-\d+\b/,
          /\bmin-w-full\b/,
          /\bmax-w-\w+\b/,
          /(?<!d-)inline-flex\b/         # Tailwind: inline-flex; Bootstrap false positive: d-inline-flex
        ].freeze

        # Only check string literals that look like CSS class attributes
        def_node_matcher :class_string?, <<~PATTERN
          (pair (sym {:class}) (str $_))
        PATTERN

        def on_pair(node)
          class_string?(node) do |class_value|
            # Split into individual classes and only check non-gm-prefixed ones
            non_gm_classes = class_value.split.reject { |c| c.start_with?("gm-") }.join(" ")
            next if non_gm_classes.empty?

            TAILWIND_PATTERNS.each do |pattern|
              next unless non_gm_classes.match?(pattern)

              add_offense(node)
              break # Only report once per node
            end
          end
        end
      end
    end
  end
end
