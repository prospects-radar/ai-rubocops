# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw HTML or Phlex DSL elements used as visual separators that
      # should instead use the Separator atom.
      #
      # Two patterns are caught:
      #
      # 1. Any element (div, Box, Span, hr, etc.) whose class string contains
      #    the word "separator" — e.g. div(class: "separator") or
      #    Box(class: "separator my-2").
      #
      # 2. Any bare hr(...) call inside glass_morph files — raw hr elements
      #    are always decorative dividers in this design system and should
      #    use the Separator atom.
      #
      # Auto-correct:
      #   • div(class: "separator")           → Separator()
      #   • hr()  /  hr(class: "my-2")        → Separator() / Separator(class: "my-2")
      #   • Box(class: "separator my-2") { }  → Separator(class: "my-2")
      #     (extra classes beyond "separator" are preserved via class:)
      #
      # NOTE: Separator does not currently accept color: or style: params.
      # For complex cases only the class: pass-through is generated; further
      # manual adjustment may be needed.
      #
      # @example Bad — raw elements with separator class
      #   div(class: "separator")
      #   Box(class: "separator my-2") { }
      #   hr(class: "my-1 opacity-25")
      #
      # @example Good — use the Separator atom
      #   Separator()
      #   Separator(class: "my-2")
      #   Separator(class: "my-1 opacity-25")
      #
      class UseRealSeparatorComponent < Base
        extend AutoCorrector

        SEPARATOR_CLASS_PATTERN = /(^| )separator( |$)/.freeze

        # Capitalized Phlex helpers and lowercase HTML elements to check for
        # the separator class pattern.
        CHECKED_ELEMENTS = %i[div span Box Span hr].freeze

        MSG_SEPARATOR_CLASS = "Use Separator() instead of %<method>s() with a " \
                              "\"separator\" class. The Separator atom provides " \
                              "consistent divider styling. Example: Separator() or " \
                              "Separator(class: \"my-2\")."

        MSG_RAW_HR = "Use Separator() instead of a raw hr() element. Inside " \
                     "glass_morph components hr is always a visual divider — " \
                     "use the Separator atom for consistent styling."

        def on_send(node)
          return if node.receiver

          method = node.method_name

          if CHECKED_ELEMENTS.include?(method)
            check_separator_class(node, method)
          end

          if method == :hr
            check_raw_hr(node)
          end
        end

        private

        # Pattern 1: element whose class contains "separator"
        def check_separator_class(node, method)
          classes = class_value(node)
          return unless classes&.match?(SEPARATOR_CLASS_PATTERN)

          add_offense(node, message: format(MSG_SEPARATOR_CLASS, method: method)) do |corrector|
            autocorrect_separator_class(corrector, node, classes)
          end
        end

        # Pattern 2: bare hr() in glass_morph files
        def check_raw_hr(node)
          return if already_caught_by_separator_class?(node)

          path = processed_source.file_path
          return unless glass_morph_file?(path)

          add_offense(node, message: MSG_RAW_HR) do |corrector|
            autocorrect_hr(corrector, node)
          end
        end

        def already_caught_by_separator_class?(node)
          classes = class_value(node)
          classes&.match?(SEPARATOR_CLASS_PATTERN)
        end

        def glass_morph_file?(path)
          path.include?("/glass_morph/") || path.include?("/layouts/glass_morph")
        end

        # Build Separator(...) replacement, stripping "separator" from the class
        # and preserving any other classes.
        def autocorrect_separator_class(corrector, node, classes)
          remaining = classes.split.reject { |c| c == "separator" }.join(" ")
          corrector.replace(node, build_separator_call(remaining, node))
        end

        # For hr: extract class value (if any) and pass it through.
        def autocorrect_hr(corrector, node)
          classes = class_value(node)
          corrector.replace(node, build_separator_call(classes&.strip, node,
                                                       include_other_args: false))
        end

        def build_separator_call(extra_classes, node, include_other_args: true)
          parts = []
          parts << "class: \"#{extra_classes}\"" if extra_classes && !extra_classes.empty?

          if include_other_args
            other_hash_children(node).each { |src| parts << src }
          end

          parts.empty? ? "Separator()" : "Separator(#{parts.join(', ')})"
        end

        # Source strings for all hash children except class:.
        def other_hash_children(node)
          hash_arg = node.arguments.find(&:hash_type?)
          return [] unless hash_arg

          hash_arg.children.filter_map do |child|
            if child.pair_type?
              key = child.key.sym_type? ? child.key.value : nil
              next if key == :class
              child.source
            elsif child.kwsplat_type?
              child.source
            end
          end
        end

        def class_value(node)
          hash_arg = node.arguments.find(&:hash_type?)
          return nil unless hash_arg

          class_pair = hash_arg.pairs.find { |p| p.key.sym_type? && p.key.value == :class }
          return nil unless class_pair

          value = class_pair.value
          if value.str_type?
            value.value
          elsif value.dstr_type?
            value.children.select(&:str_type?).map(&:value).join
          end
        end
      end
    end
  end
end
