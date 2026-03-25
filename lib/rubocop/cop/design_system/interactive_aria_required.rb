# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces ARIA attributes on interactive GlassMorph components.
      #
      # Interactive elements (buttons, links, inputs, modals, toggles) must have
      # proper ARIA labels or roles for screen reader accessibility.
      #
      # @example
      #   # bad - icon-only button without aria_label
      #   render Components::GlassMorph::Atoms::Button.new(
      #     variant: :ghost,
      #     icon: "trash"
      #   )
      #
      #   # good - button with accessible label
      #   render Components::GlassMorph::Atoms::Button.new(
      #     variant: :ghost,
      #     icon: "trash",
      #     aria_label: "Delete item"
      #   )
      #
      #   # good - button with visible text (self-describing)
      #   render Components::GlassMorph::Atoms::Button.new(
      #     variant: :primary,
      #     label: "Save changes"
      #   )
      #
      class InteractiveAriaRequired < Base
        MSG = "Interactive component `%<component>s` with icon-only display must include " \
              "`aria_label:` or `aria:` for screen reader accessibility."

        # Components that are interactive and need ARIA when icon-only
        INTERACTIVE_COMPONENTS = %w[
          Button
          LinkButton
          Link
          IconButton
        ].freeze

        def on_send(node)
          return unless in_glass_morph_file?
          return unless node.method_name == :new

          receiver = node.receiver
          return unless receiver

          component_name = extract_component_name(receiver)
          return unless INTERACTIVE_COMPONENTS.include?(component_name)

          kwargs = extract_kwargs(node)
          return unless kwargs

          # Only flag if it looks icon-only (has icon but no label/text)
          return unless icon_only?(kwargs)
          return if has_aria_attribute?(kwargs)

          add_offense(node,
            message: format(MSG, component: component_name))
        end

        private

        def in_glass_morph_file?
          file_path = processed_source.file_path
          file_path.include?("app/components/glass_morph/") ||
            file_path.include?("app/views/glass_morph/")
        end

        def extract_component_name(node)
          return nil unless node.const_type?

          parts = []
          current = node
          while current&.const_type?
            parts.unshift(current.children[1].to_s)
            current = current.children[0]
          end

          # Return just the last component name (e.g., "Button" from "Components::GlassMorph::Atoms::Button")
          parts.last
        end

        def extract_kwargs(node)
          node.arguments.detect { |arg| arg.hash_type? }
        end

        def icon_only?(kwargs)
          has_icon = false
          has_label = false

          kwargs.pairs.each do |pair|
            key_name = pair.key.value.to_s if pair.key.sym_type?
            next unless key_name

            has_icon = true if %w[icon icon_name].include?(key_name)
            has_label = true if %w[label text title content].include?(key_name)
          end

          has_icon && !has_label
        end

        def has_aria_attribute?(kwargs)
          kwargs.pairs.any? do |pair|
            next false unless pair.key.sym_type?

            key_name = pair.key.value.to_s
            key_name.start_with?("aria") || key_name == "title"
          end
        end
      end
    end
  end
end
