# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw HTML element calls in GlassMorph views that should use
      # design system atoms instead.
      #
      # Views should use the GlassMorph atom layer for structural elements:
      #   div()   -> PageContainer(), Section(), Box(), FlexRow(), FlexColumn()
      #   span()  -> Span(), Text(level: :span)
      #   p()     -> Paragraph(), Text()
      #   label() -> Label()
      #   small() -> Text(class: "small ...")
      #
      # Raw HTML table elements (table, thead, tbody, tr, td, th) are allowed
      # since the design system uses them directly with CSS classes.
      #
      # Elements inside modal structures and form helpers are also allowed.
      #
      # @example Bad
      #   div(class: "page-container") { content }
      #   span(class: "fw-semibold") { text }
      #   p(class: "small text-muted") { description }
      #
      # @example Good
      #   PageContainer { content }
      #   Span(class: "fw-semibold") { text }
      #   Paragraph(class: "small gm-text-muted") { description }
      #
      class NoRawHtmlInViews < Base
        extend AutoCorrector

        FLAGGED_ELEMENTS = %i[div span p label small].freeze

        SIMPLE_REPLACEMENTS = {
          span: "Span",
          p: "Paragraph",
          small: "Span",
          label: "Label"
        }.freeze

        SUGGESTIONS = {
          div: "Section(), Box(), FlexRow(), FlexColumn(), or PageContainer()",
          span: "Span()",
          p: "Paragraph()",
          label: "Label()",
          small: "Span(class: \"small ...\")"
        }.freeze

        def on_send(node)
          return unless in_glass_morph_views?
          return unless FLAGGED_ELEMENTS.include?(node.method_name)
          return if node.receiver
          return if inside_allowed_context?(node)

          suggestion = SUGGESTIONS[node.method_name]
          add_offense(
            node,
            message: "Use #{suggestion} instead of raw `#{node.method_name}()` in GlassMorph views."
          ) do |corrector|
            autocorrect(corrector, node)
          end
        end

        private

        def autocorrect(corrector, node)
          replacement = SIMPLE_REPLACEMENTS[node.method_name]
          corrector.replace(node.loc.selector, replacement) if replacement
        end

        def inside_allowed_context?(node)
          # Allow raw elements inside table structures
          inside_table_context?(node) ||
            # Allow inside modal div wrappers
            inside_modal_context?(node) ||
            # Allow inside form_with blocks (form field wrappers)
            inside_form_with?(node)
        end

        def inside_table_context?(node)
          node.each_ancestor(:block).any? do |ancestor|
            send_node = ancestor.send_node
            %i[table thead tbody tr td th].include?(send_node.method_name) if send_node
          end
        end

        def inside_modal_context?(node)
          parent_class = class_value_of_parent(node)
          return false unless parent_class

          parent_class.match?(/\bmodal-(content|body|footer|overlay|container|dialog)\b/)
        end

        def inside_form_with?(node)
          node.each_ancestor(:block).any? do |ancestor|
            send_node = ancestor.send_node
            send_node&.method_name == :form_with
          end
        end

        def class_value_of_parent(node)
          parent = node.parent
          return nil unless parent&.block_type?

          send_node = parent.send_node
          return nil unless send_node

          hash_arg = send_node.arguments.find(&:hash_type?)
          return nil unless hash_arg

          class_pair = hash_arg.pairs.find { |p| p.key.value == :class }
          return nil unless class_pair&.value&.str_type?

          class_pair.value.value
        end

        def in_glass_morph_views?
          processed_source.file_path.match?(%r{app/views/glass_morph/})
        end
      end
    end
  end
end
