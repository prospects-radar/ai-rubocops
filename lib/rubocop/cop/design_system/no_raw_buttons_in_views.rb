# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects raw button/link HTML in Glass Morph views that should use components.
      #
      # Views should use Button() or Link() components instead of raw a() or button()
      # elements with btn classes. Atom components are excluded since they must use
      # raw HTML by design.
      #
      # @example Bad
      #   a(href: path, class: "btn btn-success") { "Submit" }
      #   button(type: "submit", class: "btn btn-primary") { "Save" }
      #
      # @example Good
      #   Button(text: "Submit", variant: :success, href: path)
      #   Button(text: "Save", variant: :primary, type: :submit)
      #   a(href: path, class: "gm-text-link") { "View" }  # plain link is fine
      #
      class NoRawButtonsInViews < Base
        MSG_BUTTON = "Use Button(...) component instead of raw button() in views."
        MSG_LINK_BUTTON = "Use Button(href: ...) or Link(...) instead of raw a() with btn classes."

        # Matches Bootstrap btn classes (start with "btn") but NOT custom "-btn" suffix
        # classes like pagination-btn, modal-cancel-btn, auth-btn. The (^|\s) ensures
        # "btn" is at the start or after whitespace, not preceded by a hyphen.
        BTN_PATTERN = /(^|\s)btn\b/

        def on_send(node)
          return unless in_view_scope?
          return unless raw_html_element?(node)

          classes = class_value(node)
          return unless classes&.match?(BTN_PATTERN)

          if node.method_name == :button
            add_offense(node, message: MSG_BUTTON)
          elsif node.method_name == :a
            add_offense(node, message: MSG_LINK_BUTTON)
          end
        end

        private

        def raw_html_element?(node)
          return false if node.receiver

          %i[a button].include?(node.method_name)
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

        def in_view_scope?
          path = processed_source.file_path
          # Only views/components, not atom components (atoms must use raw HTML)
          (path.include?("app/views/") || path.include?("app/components/")) &&
            !path.include?("atoms/")
        end
      end
    end
  end
end
