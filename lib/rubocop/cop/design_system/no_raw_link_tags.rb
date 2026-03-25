# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw `a(href: ...)` tags in GlassMorph components and views that should
      # use design system atoms instead (Link, LinkButton, ExternalLink, Button).
      #
      # Raw anchor tags bypass the design system's consistent styling, hover states,
      # and accessibility attributes. Use the appropriate atom based on context:
      #
      # - Inline text links: `Link(text: "...", href: ...)`
      # - Card/tile footer actions: `LinkButton(text: "...", href: ..., variant: :secondary)`
      # - Row/list inline actions: `Button(text: "...", href: ..., variant: :secondary, size: :sm)`
      # - External URLs: `ExternalLink(href: ..., text: "...")`
      #
      # @example
      #   # bad
      #   a(href: path, class: "fw-medium text-primary") { "Edit" }
      #   a(href: url, target: "_blank") { "Visit" }
      #
      #   # good
      #   Link(text: "Edit", href: path, class: "fw-medium")
      #   ExternalLink(href: url, text: "Visit")
      #   LinkButton(text: "View", href: path, variant: :secondary)
      #   Button(text: "Edit", href: path, variant: :secondary, size: :sm)
      #
      class NoRawLinkTags < Base
        MSG = "Use a GlassMorph link atom (Link, LinkButton, ExternalLink) instead of raw `a(href: ...)`. " \
              "See design system skill for the decision table."

        # File-level filtering is handled by Include/Exclude in .rubocop.yml.
        # Atoms are excluded there (they use raw HTML by design).
        def on_send(node)
          return unless raw_anchor_with_href?(node)

          add_offense(node)
        end

        private

        def raw_anchor_with_href?(node)
          node.method_name == :a &&
            !node.receiver &&
            has_href_argument?(node)
        end

        def has_href_argument?(node)
          node.arguments.any? do |arg|
            next unless arg.hash_type?

            arg.pairs.any? { |pair| pair.key.value == :href }
          end
        end
      end
    end
  end
end
