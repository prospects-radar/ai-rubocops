# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects HTML elements and Phlex DSL helpers used with custom badge-style
      # class names that should instead use the Badge or TagBadge atom component.
      #
      # Catches three layers:
      # 1. Capitalized Phlex helpers (Span, Box) with *-badge suffix classes —
      #    e.g. Span(class: "stakeholder-badge"), Box(class: "engagement-badge")
      # 2. Lowercase HTML methods (div, a, span) with badge-* prefix classes —
      #    e.g. div(class: "badge-pill"), a(href: ..., class: "badge-pill")
      # 3. Raw spans with gm-badge or tag-badge classes —
      #    e.g. span(class: "gm-badge gm-badge-primary"), span(class: "tag-badge")
      #
      # Multi-segment badge class names are also caught:
      #    e.g. span(class: "criteria-weight-badge")
      #
      # This is distinct from DesignSystem/NoHardcodedHtmlComponents, which catches
      # Bootstrap badge classes like `badge bg-primary`. This cop catches custom
      # application-specific badge class patterns.
      #
      # Auto-correct (for block forms):
      #   - tag-badge classes → TagBadge(text: ...)
      #   - gm-badge gm-badge-{variant} classes → Badge(text: ..., variant: :primary)
      #   - other *-badge classes → Badge(text: ..., class: "original-class")
      #
      # The Badge atom supports: text:, variant: (:success, :warning, :danger,
      # :info, :primary, :secondary), class:, title:, and all standard attrs.
      # The TagBadge atom supports: text:, variant: (:default, :task_status,
      # :readiness, :action, :bootstrap, etc), class:
      #
      # @example Bad — Phlex helpers with *-badge suffix
      #   Span(class: "decision-maker-badge") { "Decision Maker" }
      #   Span(class: "stakeholder-badge", style: "background: #fef3c7; color: #92400e") { ... }
      #   Box(class: "engagement-badge") { tier_level }
      #
      # @example Bad — raw HTML with badge-* prefix
      #   div(class: "badge-pill") { Icon(...); plain "Enschede, NL" }
      #
      # @example Bad — raw spans with gm-badge or tag-badge
      #   span(class: "tag-badge") { "Projectontwikkeling" }
      #   span(class: "gm-badge gm-badge-primary ms-1") { "👔 Executive" }
      #   span(class: "criteria-weight-badge") { "0.11% Gewicht" }
      #
      # @example Good — use Badge or TagBadge atom
      #   TagBadge(text: "Projectontwikkeling")
      #   Badge(text: "👔 Executive", variant: :primary, class: "ms-1")
      #   Badge(text: "0.11% Gewicht", class: "criteria-weight-badge")
      #   Badge(text: tier_text, variant: :warning, title: tooltip_text)
      #
      class UseRealBadgeComponent < Base
        extend AutoCorrector

        # Matches *-badge suffix (including multi-segment like criteria-weight-badge)
        # and badge-* prefix. Also matches gm-badge and tag-badge directly.
        # [\w-]+ allows hyphens within the prefix so compound names are caught.
        BADGE_CLASS_PATTERN = /\b[\w-]+-badge\b|\bbadge-[\w-]+\b|\bgm-badge\b|\btag-badge\b/

        # Bootstrap badge pattern: "badge bg-*" or "badge text-*" (space-separated).
        BOOTSTRAP_BADGE_PATTERN = /\bbadge\s+(bg-|text-)/

        # Maps Bootstrap bg-* color to Badge color symbol.
        BOOTSTRAP_COLOR_MAP = {
          "bg-primary"        => :blue,
          "bg-secondary"      => :slate,
          "bg-success"        => :green,
          "bg-danger"         => :red,
          "bg-warning"        => :amber,
          "bg-info"           => :teal,
          "bg-info-subtle"    => :teal,
          "bg-success-subtle" => :green,
          "bg-danger-subtle"  => :red,
          "bg-warning-subtle" => :amber
        }.freeze

        # Explicit class names that should use Badge/TagBadge regardless of naming pattern.
        EXPLICIT_BADGE_CLASSES = %w[word-cloud-item].freeze

        # Capitalized Phlex DSL helpers: check for *-badge suffix classes.
        CAPITALIZED_HELPERS = %i[Span Box Paragraph].freeze

        # Lowercase HTML methods: check for badge-* prefix classes (e.g. badge-pill).
        LOWERCASE_HELPERS = %i[div a span].freeze

        ALL_HELPERS = (CAPITALIZED_HELPERS + LOWERCASE_HELPERS).freeze

        MSG = "Use Badge(...) or TagBadge(...) instead of %<method>s() with a badge-style " \
              "class (%<classes>s). Badge supports variant: (:success, :warning, :danger, " \
              ":info, :primary, :secondary). TagBadge supports tag-badge class variants. " \
              "Example: Badge(text: \"...\", variant: :primary) or TagBadge(text: \"...\")."

        # Detect block form: span(class: "...badge...") { content } — autocorrectable
        def on_block(node) # rubocop:disable InternalAffairs/NumblockHandler
          send_node = node.send_node
          return if send_node.receiver

          method = send_node.method_name
          return unless ALL_HELPERS.include?(method)

          classes = class_value(send_node)
          return unless badge_classes?(classes)

          add_offense(node, message: format(MSG, method: method, classes: classes.strip)) do |corrector|
            autocorrect(corrector, node, send_node, classes)
          end
        end

        # Detect send form without block — flag only, no autocorrect
        def on_send(node)
          return if node.receiver
          return if node.parent&.block_type?

          method = node.method_name
          return unless ALL_HELPERS.include?(method)

          classes = class_value(node)
          return unless badge_classes?(classes)

          add_offense(node, message: format(MSG, method: method, classes: classes.strip))
        end

        private

        def autocorrect(corrector, block_node, send_node, classes)
          body_source = block_body_source(block_node)
          replacement = build_badge_call(send_node, classes, body_source)
          corrector.replace(block_node, replacement)
        end

        def badge_classes?(classes)
          return false unless classes

          classes.match?(BADGE_CLASS_PATTERN) ||
            classes.match?(BOOTSTRAP_BADGE_PATTERN) ||
            classes.split.any? { |c| EXPLICIT_BADGE_CLASSES.include?(c) }
        end

        def build_badge_call(send_node, classes, body_source)
          class_list = classes.split
          other_args = other_hash_children(send_node)

          if class_list.include?("tag-badge")
            build_tag_badge(class_list, body_source, other_args)
          elsif class_list.include?("gm-badge")
            build_gm_badge(class_list, body_source, other_args)
          elsif class_list.include?("word-cloud-item")
            build_word_cloud_badge(class_list, body_source, other_args)
          elsif class_list.include?("criteria-weight-badge")
            build_tag_badge_variant(class_list, "criteria-weight-badge", :criteria_weight, body_source, other_args)
          elsif classes.match?(BOOTSTRAP_BADGE_PATTERN)
            build_bootstrap_badge(class_list, body_source, other_args)
          else
            build_generic_badge(classes, body_source, other_args)
          end
        end

        # tag-badge → TagBadge(text: ...) stripping the tag-badge class
        def build_tag_badge(class_list, body_source, other_args)
          extra = (class_list - [ "tag-badge" ]).join(" ")
          parts = [ "text: #{body_source}" ]
          parts << "class: \"#{extra}\"" unless extra.empty?
          parts.concat(other_args)
          "TagBadge(#{parts.join(', ')})"
        end

        # gm-badge gm-badge-{variant} → Badge(text: ..., variant: :primary, ...)
        def build_gm_badge(class_list, body_source, other_args)
          variant_class = class_list.find { |c| c.match?(/\Agm-badge-(?!sm\z|round\z)\w+\z/) }
          variant = variant_class&.sub("gm-badge-", "")
          leftover = class_list - [ "gm-badge", variant_class ].compact
          parts = [ "text: #{body_source}" ]
          parts << "variant: :#{variant}" if variant
          parts << "class: \"#{leftover.join(' ')}\"" unless leftover.empty?
          parts.concat(other_args)
          "Badge(#{parts.join(', ')})"
        end

        # Generic helper: known class → TagBadge(text: ..., variant: :symbol)
        def build_tag_badge_variant(class_list, known_class, variant_sym, body_source, other_args)
          extra = (class_list - [ known_class ]).join(" ")
          parts = [ "text: #{body_source}", "variant: :#{variant_sym}" ]
          parts << "class: \"#{extra}\"" unless extra.empty?
          parts.concat(other_args)
          "TagBadge(#{parts.join(', ')})"
        end

        # word-cloud-item → TagBadge(text: ..., variant: :word_cloud)
        # Size modifiers (size-xl, size-lg, etc.) passed through as class:
        def build_word_cloud_badge(class_list, body_source, other_args)
          build_tag_badge_variant(class_list, "word-cloud-item", :word_cloud, body_source, other_args)
        end

        # Bootstrap badge bg-{color} → Badge(text: ..., variant: :color)
        # Strips bootstrap-specific classes (bg-*, text-*, bg-opacity-*); keeps layout classes.
        def build_bootstrap_badge(class_list, body_source, other_args)
          variant = class_list.filter_map { |c| BOOTSTRAP_COLOR_MAP[c] }.first
          strip = /\Abadge\z|\Abg-|\Atext-[a-z]|\Abg-opacity-/
          leftover = class_list.reject { |c| c == "badge" || c.match?(strip) }.join(" ")
          parts = [ "text: #{body_source}" ]
          parts << "variant: :#{variant}" if variant
          parts << "class: \"#{leftover}\"" unless leftover.empty?
          parts.concat(other_args)
          "Badge(#{parts.join(', ')})"
        end

        # Other *-badge classes → Badge(text: ..., class: "original-class")
        def build_generic_badge(classes, body_source, other_args)
          parts = [ "text: #{body_source}", "class: \"#{classes}\"" ]
          parts.concat(other_args)
          "Badge(#{parts.join(', ')})"
        end

        # Extract block body as Ruby source. For single str literals, use quoted form.
        def block_body_source(block_node)
          body = block_node.body
          return '""' unless body

          body.source
        end

        # Returns source strings for all hash children except class:
        def other_hash_children(send_node)
          hash_arg = send_node.arguments.find(&:hash_type?)
          return [] unless hash_arg

          hash_arg.children.filter_map do |child|
            next unless child.pair_type?

            key = child.key.sym_type? ? child.key.value : nil
            next if key == :class

            child.source
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
            # For interpolated strings, join literal parts — enough to detect the pattern
            value.children.select(&:str_type?).map(&:value).join
          end
        end
      end
    end
  end
end
