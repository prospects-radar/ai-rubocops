# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects Badge() calls that pass a `class:` keyword argument.
      #
      # Passing `class:` to Badge() is a signal that the badge should be
      # expressed as a named builder method instead, so the class is
      # encapsulated and call sites stay clean.
      #
      # The Badge atom has builder methods for all common patterns:
      #   Badge.engagement(tier_level)       # class: "engagement-badge" built in
      #   Badge.status(:active)              # class + variant built in
      #   Badge.tier(:pro)                   # gradient + icon built in
      #   Badge.signal("hiring", text: ...)  # color mapping built in
      #   Badge.stat("+3", variant: :new)    # stat-badge class built in
      #
      # When no builder exists yet, create one that merges the predefined class
      # with the optional override via attrs.delete(:class).
      #
      # The only accepted use of `class:` on Badge() is additive spacing or
      # layout adjustment (e.g. class: "ms-2") that genuinely belongs at the
      # call site. Use the builder methods for semantic badge styles.
      #
      # @example Bad — style encoded at call site via class:
      #   Badge(text: @stakeholder.tier_level.to_s, variant: :secondary, class: "engagement-badge")
      #   Badge(text: status, class: "home-lead-source source-system")
      #   Badge(text: label, variant: :info, class: "criteria-weight-badge fw-bold")
      #
      # @example Good — use a builder method; class: reserved for layout tweaks
      #   Badge.engagement(@stakeholder.tier_level)
      #   Badge.source(:system)
      #   Badge.engagement(@stakeholder.tier_level, class: "ms-2")   # layout-only override
      #
      class NoClassOnBadge < Base
        MSG = "Avoid passing class: to Badge(). Encapsulate the style in a " \
              "Badge builder method (e.g. Badge.engagement, Badge.status, " \
              "Badge.tier) so the CSS class is defined once and call sites " \
              "stay clean. Reserve class: for layout-only overrides like " \
              "\"ms-2\" or \"mt-1\"."

        # CSS classes that are layout-only and therefore acceptable as overrides.
        LAYOUT_ONLY_PATTERN = /\A[\s]*(m[stbexylr]?-\d|p[stbexylr]?-\d|gap-\d|d-|w-|flex|align|justify|order|float|col-|text-[se]|invisible|hidden|sr-only)[\s\w-]*\z/i.freeze

        def on_send(node)
          return if node.receiver
          return unless node.method_name == :Badge

          class_value = badge_class_value(node)
          return unless class_value
          return if layout_only?(class_value)

          add_offense(node)
        end

        private

        def badge_class_value(node)
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

        def layout_only?(classes)
          classes.strip.split.all? { |c| c.match?(LAYOUT_ONLY_PATTERN) }
        end
      end
    end
  end
end
