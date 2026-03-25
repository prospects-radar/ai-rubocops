# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Prevents raw HTML method calls inside GlassMorph organism components.
      #
      # Organisms must compose atoms and molecules — they must not call raw HTML
      # methods like div() or span() directly. Use Box and Span for structural
      # wrappers, and the appropriate named atom for semantic elements (DEC-030).
      #
      # @example Bad — in app/components/glass_morph/organisms/my_organism.rb
      #   div(class: "my-wrapper") { content }
      #   span(class: "my-badge") { text }
      #   h3(class: "title") { title }
      #   i(class: "bi bi-star") {}
      #   button(class: "btn btn-primary") { "Save" }
      #   a(href: path, class: "btn btn-secondary") { "Cancel" }
      #
      # @example Good — in app/components/glass_morph/organisms/my_organism.rb
      #   Box(class: "my-wrapper") { content }
      #   Span(class: "my-badge") { text }
      #   Heading(level: 3, text: title)
      #   Icon(name: "star")
      #   Button(text: "Save", variant: :primary)
      #   Button(text: "Cancel", href: path, variant: :secondary)
      #
      # @example Allowed raw a() patterns (design system explicitly permits these):
      #   a(class: "gm-text-link", href: path) { "View details" }       # inline text link
      #   a(href: path, data: { turbo_frame: "modal" }) { "Open" }      # modal/turbo-frame link
      #   a(href: url, target: "_blank") { "External" }                 # external link
      #
      class NoRawHtmlInOrganisms < Base
        extend AutoCorrector

        SIMPLE_REPLACEMENTS = {
          div:  "Box",
          span: "Span",
          p:    "Paragraph",
          li:   "ListItem"
        }.freeze

        HEADING_LEVELS = { h1: 1, h2: 2, h3: 3, h4: 4, h5: 5, h6: 6 }.freeze

        # Classes that indicate an <a> is styled as a button and should use Button(href:)
        BTN_LIKE_PATTERN = /(^|\s)(btn|button-primary|button-secondary|button-tertiary|auth-btn)\b/

        ATOM_SUGGESTIONS = {
          div:    "Box(...)",
          span:   "Span(...)",
          p:      "Paragraph(...)",
          h1:     "Heading(level: 1, ...)",
          h2:     "Heading(level: 2, ...)",
          h3:     "Heading(level: 3, ...)",
          h4:     "Heading(level: 4, ...)",
          h5:     "Heading(level: 5, ...)",
          h6:     "Heading(level: 6, ...)",
          i:      "Icon(name: ..., style: ...)",
          a:      "Button(href: ...) for btn-styled links",
          button: "Button(...)",
          li:     "ListItem(...)"
        }.freeze

        RAW_HTML_ELEMENTS = ATOM_SUGGESTIONS.keys.freeze

        def on_send(node)
          return unless in_organisms_scope?
          return unless RAW_HTML_ELEMENTS.include?(node.method_name)
          return if node.receiver
          return if allowed_anchor?(node)
          return if allowed_structural_button?(node)

          atom = ATOM_SUGGESTIONS[node.method_name]
          add_offense(node, message: "Use #{atom} instead of raw #{node.method_name}() in organisms.") do |corrector|
            autocorrect(corrector, node)
          end
        end

        private

        def autocorrect(corrector, node)
          method_name = node.method_name

          if (replacement = SIMPLE_REPLACEMENTS[method_name])
            corrector.replace(node.loc.selector, replacement)
          elsif (level = HEADING_LEVELS[method_name])
            autocorrect_heading(corrector, node, level)
          end
          # i, a, button — too context-dependent for safe autocorrect
        end

        def autocorrect_heading(corrector, node, level)
          corrector.replace(node.loc.selector, "Heading")

          if node.arguments.any?
            corrector.insert_before(node.arguments.first.source_range, "level: #{level}, ")
          elsif node.loc.begin
            corrector.insert_after(node.loc.begin, "level: #{level}")
          end
        end

        # The design system explicitly permits these a() patterns without conversion:
        #   - target: "_blank"  → external link (use ExternalLink for standalone display)
        #   - data turbo_frame  → Turbo-frame / modal navigation
        #   - no btn-like class → inline text link (use class: "gm-text-link")
        # Allows button() used as a structural click-target wrapper with a dynamic class.
        # Example: button(type: "button", class: card_link_classes) { complex_content }
        # These can't be replaced with Button(text:) since Button doesn't support blocks,
        # and the class is a method call so we can't statically verify btn styling.
        def allowed_structural_button?(node)
          return false unless node.method_name == :button

          class_pair = hash_arg(node)&.pairs&.find { |p| p.key.value == :class }
          return false unless class_pair

          # If class is a method/variable reference (not a string literal), allow it
          # as a structural wrapper — we can't statically evaluate its value.
          !class_pair.value.str_type?
        end

        def allowed_anchor?(node)
          return false unless node.method_name == :a

          # External links
          return true if has_attribute?(node, :target)

          # Turbo-frame navigation
          return true if turbo_frame_link?(node)

          # Not styled as a button — plain text/nav link
          classes = class_value(node)
          return true unless classes&.match?(BTN_LIKE_PATTERN)

          false
        end

        def has_attribute?(node, attr_name)
          hash_arg(node)&.pairs&.any? { |p| p.key.value == attr_name } || false
        end

        def turbo_frame_link?(node)
          data_hash = hash_arg(node)&.pairs&.find { |p| p.key.value == :data }
          return false unless data_hash&.value&.hash_type?

          data_hash.value.pairs.any? { |p| p.key.value == :turbo_frame }
        end

        def class_value(node)
          pair = hash_arg(node)&.pairs&.find { |p| p.key.value == :class }
          return nil unless pair&.value&.str_type?

          pair.value.value
        end

        def hash_arg(node)
          node.arguments.find(&:hash_type?)
        end

        def in_organisms_scope?
          processed_source.file_path.match?(%r{app/components/glass_morph/organisms/})
        end
      end
    end
  end
end
