# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw `span(class: "badge ...")` in components that should use
      # the `Badge` atom instead.
      #
      # Raw badge spans bypass the design system's rich Badge API with builder
      # methods for scores, statuses, counts, priorities, etc.
      #
      # @example
      #   # bad
      #   span(class: "badge bg-success") { "Active" }
      #   span(class: "badge rounded-pill bg-primary") { count }
      #
      #   # good
      #   Badge.status(status: :success, text: "Active")
      #   Badge.count(count: count)
      #   Badge.score(score: 85)
      #
      class NoRawBadgeSpans < Base
        extend AutoCorrector

        MSG = "Use `Badge.status(...)`, `Badge.count(...)`, or other Badge builder methods " \
              "instead of raw `span(class: \"badge ...\")`. See design system skill for Badge API."

        BADGE_PATTERN = /(^|\s)badge(\s|$)/

        # bg-* classes to Badge variant symbols
        VARIANT_MAP = {
          "bg-primary" => :primary,
          "bg-secondary" => :secondary,
          "bg-success" => :success,
          "bg-danger" => :danger,
          "bg-warning" => :warning,
          "bg-info" => :info,
          "bg-light" => :light,
          "bg-dark" => :dark
        }.freeze

        # Classes consumed by the Badge atom
        STRIP_CLASSES = (%w[badge rounded-pill] + VARIANT_MAP.keys +
                         %w[text-white text-dark text-light]).freeze

        def on_send(node)
          return unless raw_span_or_div?(node)

          classes = class_value(node)
          return unless classes&.match?(BADGE_PATTERN)

          add_offense(node) do |corrector|
            autocorrect_badge(corrector, node, classes) if static_class?(node)
          end
        end

        private

        def raw_span_or_div?(node)
          !node.receiver && %i[span div].include?(node.method_name)
        end

        def autocorrect_badge(corrector, node, classes)
          variant = extract_variant(classes)
          text = extract_simple_text(node)
          remaining = remaining_classes(classes)

          params = []
          params << "text: #{text.inspect}" if text
          params << "variant: :#{variant}" if variant
          params << "class: \"#{remaining}\"" if remaining

          # Preserve non-class hash attributes
          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          if hash_arg
            hash_arg.pairs.each do |pair|
              next if pair.key.value == :class

              params << "#{pair.key.value}: #{pair.value.source}"
            end
          end

          if text
            # Simple text: no block needed
            replacement = "Badge.label(#{params.join(', ')})"
            range = node.block_node ? node.block_node.source_range : node.source_range
            corrector.replace(range, replacement)
          elsif node.block_node&.body
            # Complex block: keep block
            body_source = node.block_node.body.source
            call = "Badge.label(#{params.join(', ')})"
            if node.block_node.braces?
              replacement = "#{call} { #{body_source} }"
            else
              replacement = "#{call} do\n#{body_source}\nend"
            end
            corrector.replace(node.block_node.source_range, replacement)
          else
            replacement = "Badge.label(#{params.join(', ')})"
            corrector.replace(node.source_range, replacement)
          end
        end

        def extract_variant(classes)
          VARIANT_MAP.each do |css_class, variant_sym|
            return variant_sym if classes.include?(css_class)
          end
          :secondary # default
        end

        def extract_simple_text(node)
          return nil unless node.block_node&.body

          body = node.block_node.body
          return body.value if body.str_type?

          nil
        end

        def remaining_classes(classes)
          tokens = classes.split
          tokens.reject! { |t| STRIP_CLASSES.include?(t) }
          result = tokens.join(" ").strip
          result.empty? ? nil : result
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
