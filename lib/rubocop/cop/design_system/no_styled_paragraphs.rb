# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw `p()` calls with color or size styling classes that should
      # use the `Paragraph` atom instead.
      #
      # Plain `p { "text" }` without styling is fine — the cop only flags
      # paragraphs with classes that the Paragraph atom's color/size API handles,
      # such as `text-muted`, `text-light`, `small`, `fs-5`, etc.
      #
      # @example
      #   # bad — these use classes the Paragraph atom handles
      #   p(class: "text-muted") { "Description" }
      #   p(class: "small text-muted-light") { "Caption" }
      #   p(class: "fs-5") { "Large text" }
      #   p(class: "text-light mb-0") { "Light text" }
      #
      #   # good
      #   Paragraph(color: :muted) { "Description" }
      #   Paragraph(color: :muted_light, size: :sm) { "Caption" }
      #   Paragraph(size: :lg) { "Large text" }
      #   Paragraph(color: :muted_light) { "Light text" }
      #
      #   # also good — plain p() without styling classes is fine
      #   p { "Simple text" }
      #   p(class: "mb-3") { "Spaced text" }
      #
      class NoStyledParagraphs < Base
        extend AutoCorrector

        MSG = "Use `Paragraph(color: ..., size: ...)` instead of raw `p()` with text styling classes. " \
              "The Paragraph atom standardizes color and size tokens."

        # Color classes that map to Paragraph color: parameter
        COLOR_PATTERN = /\btext-(muted|light|dark|white|secondary)\b/

        # Size classes that map to Paragraph size: parameter
        SIZE_PATTERN = /\b(small|fs-[4-6]|text-(sm|md|lg|xs))\b/

        # Complete mapping from CSS class to Paragraph color: value
        COLOR_MAP = {
          "text-muted" => :muted,
          "text-secondary" => :muted,
          "text-light" => :muted_light,
          "text-white" => :muted_light,
          "text-dark" => :dark
        }.freeze

        # Complete mapping from CSS class to Paragraph size: value
        SIZE_MAP = {
          "small" => :sm,
          "text-xs" => :xs,
          "text-sm" => :sm,
          "text-md" => :md,
          "text-lg" => :lg,
          "fs-5" => :lg,
          "fs-4" => :lg,
          "fs-6" => :sm
        }.freeze

        # All classes we strip (color + size tokens handled by the atom)
        STRIPPABLE_CLASSES = (COLOR_MAP.keys + SIZE_MAP.keys).freeze

        def on_send(node)
          return unless raw_paragraph?(node)

          classes = class_value(node)
          return unless classes

          return unless classes.match?(COLOR_PATTERN) || classes.match?(SIZE_PATTERN)

          add_offense(node) do |corrector|
            autocorrect_paragraph(corrector, node, classes) if static_class?(node)
          end
        end

        private

        def raw_paragraph?(node)
          !node.receiver && node.method_name == :p
        end

        def autocorrect_paragraph(corrector, node, classes)
          params = []
          color = extract_color(classes)
          size = extract_size(classes)
          remaining = remaining_classes(classes)

          # Omit defaults: color: :muted_light, size: :md
          params << "color: :#{color}" if color && color != :muted_light
          params << "size: :#{size}" if size && size != :md

          # Preserve non-color/size classes
          params << "class: \"#{remaining}\"" if remaining

          # Preserve other hash attributes (data, id, style, etc.)
          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          if hash_arg
            hash_arg.pairs.each do |pair|
              next if pair.key.value == :class

              params << "#{pair.key.value}: #{pair.value.source}"
            end
          end

          replacement = build_replacement(params, node)
          range = node.block_node ? node.block_node.source_range : node.source_range
          corrector.replace(range, replacement)
        end

        def extract_color(classes)
          COLOR_MAP.each do |css_class, color_sym|
            return color_sym if classes.include?(css_class)
          end
          nil
        end

        def extract_size(classes)
          SIZE_MAP.each do |css_class, size_sym|
            return size_sym if classes.include?(css_class)
          end
          nil
        end

        def remaining_classes(classes)
          tokens = classes.split
          tokens.reject! { |t| STRIPPABLE_CLASSES.include?(t) }
          result = tokens.join(" ").strip
          result.empty? ? nil : result
        end

        def build_replacement(params, node)
          call = "Paragraph(#{params.join(', ')})"

          if node.block_node&.body
            body_source = node.block_node.body.source
            if node.block_node.braces?
              "#{call} { #{body_source} }"
            else
              "#{call} do\n#{body_source}\nend"
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
