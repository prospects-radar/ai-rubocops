# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw h1–h6 Phlex DSL calls with Bootstrap font utility classes
      # that should use the Heading atom instead.
      #
      # The trigger is the presence of Bootstrap font-weight (fw-*), font-size
      # (fs-*), or text-colour utilities in the class string — these signal
      # that the author is manually styling a heading rather than delegating
      # to the design system.  Design-token class names such as "card-title" or
      # "event-title" are not flagged.
      #
      # Auto-correct:
      #   1. Replaces the tag with Heading(level: N, ...)
      #   2. Maps known text-colour utilities to color: (:light/:dark/:muted)
      #      and strips them from the class string.
      #   3. Strips font-weight utilities (fw-*) — the Heading atom manages weight.
      #   4. Passes remaining classes via class: "...".
      #   5. Preserves the block and all other hash arguments unchanged.
      #
      # @example Bad — Bootstrap utilities on raw heading
      #   h3(class: "fw-semibold text-dark mb-3") { t(".title") }
      #   h2(class: "fs-4 fw-bold text-body mb-4") { @title }
      #   h5(class: "fw-semibold text-light mb-3") { "Preview" }
      #
      # @example Good — use the Heading atom
      #   Heading(level: 3, color: :dark, class: "mb-3") { t(".title") }
      #   Heading(level: 2, color: :dark, class: "fs-4 mb-4") { @title }
      #   Heading(level: 5, color: :light, class: "mb-3") { "Preview" }
      #
      class UseRealHeadingComponent < Base
        extend AutoCorrector

        HEADING_TAGS = %i[h1 h2 h3 h4 h5 h6].freeze

        # Bootstrap font-weight utilities — managed by the Heading atom
        FONT_WEIGHT_CLASSES = %w[fw-bold fw-semibold fw-medium fw-normal fw-light].freeze

        # Trigger: any of these Bootstrap utilities in the class string
        HEADING_UTILITY_PATTERN = /
          \b(?:
            fw-bold|fw-semibold|fw-medium|fw-light|fw-normal|  # font weight
            fs-[1-6]|                                           # font size
            text-body\b|text-dark\b|text-light\b|text-white\b| # colour utilities
            text-muted\b|text-secondary\b|text-body-secondary\b
          )
        /x.freeze

        # Bootstrap text-colour → Heading color: param
        COLOR_MAP = {
          "text-body"           => :dark,
          "text-dark"           => :dark,
          "text-black"          => :dark,
          "text-light"          => :light,
          "text-white"          => :light,
          "text-muted"          => :muted,
          "text-secondary"      => :muted,
          "text-body-secondary" => :muted
        }.freeze

        MSG = "Use Heading(level: %<level>d, ...) instead of %<tag>s() with " \
              "Bootstrap font utility classes. The Heading atom provides consistent " \
              "typography via color: (:light, :dark, :muted) and removes the need " \
              "for fw-* and text-colour utility classes."

        def on_send(node)
          return if node.receiver
          return unless HEADING_TAGS.include?(node.method_name)

          classes = class_value(node)
          return unless classes&.match?(HEADING_UTILITY_PATTERN)

          level = node.method_name.to_s[1].to_i
          add_offense(node, message: format(MSG, level: level, tag: node.method_name)) do |corrector|
            autocorrect(corrector, node, level, classes)
          end
        end

        private

        def autocorrect(corrector, node, level, classes)
          corrector.replace(node, build_replacement(node, level, classes))
        end

        def build_replacement(node, level, classes)
          parts = [ "level: #{level}" ]

          color, remaining = extract_color_and_remaining(classes)

          if color
            parts << "color: :#{color}"
          elsif contains_unmapped_text_color?(classes)
            # Suppress the default :light to avoid conflicting with an explicit
            # text-* class that we cannot map to a Heading color param.
            parts << "color: nil"
          end

          parts << "class: \"#{remaining}\"" unless remaining.empty?

          other_hash_children(node).each { |src| parts << src }

          "Heading(#{parts.join(', ')})"
        end

        # Returns [color_symbol_or_nil, remaining_class_string]
        def extract_color_and_remaining(classes)
          mapped_color = nil
          kept = []

          classes.split.each do |cls|
            if !mapped_color && COLOR_MAP.key?(cls)
              mapped_color = COLOR_MAP[cls]
              # don't add to kept — strip this class
            elsif FONT_WEIGHT_CLASSES.include?(cls)
              # strip font-weight utilities
            else
              kept << cls
            end
          end

          [ mapped_color, kept.join(" ") ]
        end

        def contains_unmapped_text_color?(classes)
          classes.split.any? do |cls|
            cls.start_with?("text-") && !COLOR_MAP.key?(cls)
          end
        end

        # Returns source strings for all hash children except the class: pair.
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
