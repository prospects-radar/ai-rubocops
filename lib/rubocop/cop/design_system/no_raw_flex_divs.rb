# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw `div(class: "d-flex ...")` in components that should use
      # `FlexRow` or `FlexColumn` atoms instead.
      #
      # Raw flex divs bypass the design system's standardized gap sizes,
      # alignment helpers, and responsive behavior. Use the appropriate atom:
      #
      # - Horizontal layout: `FlexRow(gap: :md, align: :center)`
      # - Vertical layout: `FlexColumn(gap: :sm)`
      #
      # @example
      #   # bad
      #   div(class: "d-flex align-items-center gap-2") { ... }
      #   div(class: "d-flex flex-column") { ... }
      #
      #   # good
      #   FlexRow(gap: :sm, align: :center) { ... }
      #   FlexColumn(gap: :sm) { ... }
      #
      class NoRawFlexDivs < Base
        extend AutoCorrector

        MSG = "Use `FlexRow(...)` or `FlexColumn(...)` instead of raw `div(class: \"d-flex ...\")`. " \
              "See design system skill for layout atoms."

        FLEX_PATTERN = /(^|\s)d-flex(\s|$)/

        # Bootstrap gap-N to atom gap: symbol
        GAP_MAP = {
          "gap-1" => :xs,
          "gap-2" => :sm,
          "gap-3" => :md,
          "gap-4" => :lg,
          "gap-5" => :xl
        }.freeze

        # CSS class to atom align: symbol
        ALIGN_MAP = {
          "align-items-start" => :start,
          "align-items-center" => :center,
          "align-items-end" => :end,
          "align-items-stretch" => :stretch,
          "align-items-baseline" => :baseline
        }.freeze

        # CSS class to atom justify: symbol
        JUSTIFY_MAP = {
          "justify-content-start" => :start,
          "justify-content-center" => :center,
          "justify-content-end" => :end,
          "justify-content-between" => :between,
          "justify-content-around" => :around,
          "justify-content-evenly" => :evenly
        }.freeze

        # All classes we consume (stripped from the remaining class string)
        CONSUMED_CLASSES = (%w[d-flex flex-row flex-column] + GAP_MAP.keys + ALIGN_MAP.keys + JUSTIFY_MAP.keys).freeze

        def on_send(node)
          return unless raw_div?(node)

          classes = class_value(node)
          return unless classes&.match?(FLEX_PATTERN)

          add_offense(node) do |corrector|
            autocorrect_flex(corrector, node, classes) if static_class?(node)
          end
        end

        private

        def raw_div?(node)
          !node.receiver && node.method_name == :div
        end

        def autocorrect_flex(corrector, node, classes)
          is_column = classes.include?("flex-column")
          component = is_column ? "FlexColumn" : "FlexRow"

          params = []

          # Extract gap
          gap = extract_gap(classes)
          # FlexRow/FlexColumn default gap is :md — omit if default
          params << "gap: :#{gap}" if gap && gap != :md

          # FlexRow supports align: and justify: params; FlexColumn does not
          unless is_column
            align = extract_align(classes)
            # FlexRow default align is :start — omit if default
            params << "align: :#{align}" if align && align != :start

            justify = extract_justify(classes)
            # FlexRow default justify is :start — omit if default
            params << "justify: :#{justify}" if justify && justify != :start
          end

          # Remaining classes that the atom doesn't handle
          remaining = remaining_classes(classes, is_column)
          params << "class: \"#{remaining}\"" if remaining

          # Preserve non-class hash attributes (data, id, style, etc.)
          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          if hash_arg
            hash_arg.pairs.each do |pair|
              next if pair.key.value == :class

              params << "#{pair.key.value}: #{pair.value.source}"
            end
          end

          replacement = build_replacement(component, params, node)
          range = node.block_node ? node.block_node.source_range : node.source_range
          corrector.replace(range, replacement)
        end

        def extract_gap(classes)
          GAP_MAP.each do |css_class, gap_sym|
            return gap_sym if classes.include?(css_class)
          end
          nil
        end

        def extract_align(classes)
          ALIGN_MAP.each do |css_class, align_sym|
            return align_sym if classes.include?(css_class)
          end
          nil
        end

        def extract_justify(classes)
          JUSTIFY_MAP.each do |css_class, justify_sym|
            return justify_sym if classes.include?(css_class)
          end
          nil
        end

        def remaining_classes(classes, is_column)
          tokens = classes.split
          tokens.reject! { |t| CONSUMED_CLASSES.include?(t) }

          # For FlexColumn, align/justify classes stay as residual (not supported as params)
          # They're already NOT in CONSUMED_CLASSES for FlexColumn, so nothing extra needed here.
          # Actually, CONSUMED_CLASSES includes them. For column, we need to keep them.
          if is_column
            align = ALIGN_MAP.keys.find { |k| classes.include?(k) }
            justify = JUSTIFY_MAP.keys.find { |k| classes.include?(k) }
            tokens << align if align
            tokens << justify if justify
          end

          result = tokens.join(" ").strip
          result.empty? ? nil : result
        end

        def build_replacement(component, params, node)
          call = params.empty? ? component : "#{component}(#{params.join(', ')})"

          if node.block_node&.body
            body_source = node.block_node.body.source
            if node.block_node.braces?
              "#{call} { #{body_source} }"
            else
              "#{call} do\n#{body_source}\nend"
            end
          elsif node.block_node
            # Empty block
            if node.block_node.braces?
              "#{call} { }"
            else
              "#{call} do\nend"
            end
          else
            call
          end
        end

        def static_class?(node)
          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return true unless hash_arg

          class_pair = hash_arg.pairs.find { |pair| pair.key.value == :class }
          return true unless class_pair

          class_pair.value.str_type?
        end

        def class_value(node)
          return nil unless node.arguments.any?

          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return nil unless hash_arg

          class_pair = hash_arg.pairs.find { |pair| pair.key.value == :class }
          return nil unless class_pair

          value_node = class_pair.value
          if value_node.str_type?
            value_node.value
          elsif value_node.dstr_type?
            value_node.children.select(&:str_type?).map(&:value).join
          end
        end
      end
    end
  end
end
