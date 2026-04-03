# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces NewUI component standard API conventions.
      #
      # All NewUI components must follow these standards:
      # 1. Inherit from Components::GlassMorph::BaseComponent
      # 2. Have a view_template method
      # 3. Use hybrid approach: semantic parameters + css_class escape hatch
      # 4. Include frozen_string_literal pragma
      # 5. Use proper namespacing
      # 6. Use tid() for test automation data attributes
      # 7. Never contain business logic or database queries
      #
      class StandardApi < Base
        extend AutoCorrector

        MSG_NO_FROZEN_STRING_LITERAL = "NewUI components must include `# frozen_string_literal: true` at the top."
        MSG_WRONG_BASE_CLASS = "NewUI components must inherit from `Components::GlassMorph::BaseComponent`, not `%<base_class>s`."
        MSG_NO_VIEW_TEMPLATE = "NewUI components must define a `view_template` method."
        MSG_USE_CSS_CLASS = "Use `css_class:` parameter instead of `additional_classes:` for consistency."
        MSG_WRONG_NAMESPACE = "NewUI components must be in `Components::GlassMorph::{Atoms|Molecules|Organisms}` for reusable components or `Components::GlassMorph::{Feature}` for feature-specific pages."
        MSG_DATABASE_QUERY = "NewUI components should not contain database queries. Receive data via `initialize`."

        def on_class(node)
          return unless in_glass_morph_component?

          check_frozen_string_literal(node)
          check_base_class(node)
          check_namespace(node)
          check_required_methods(node)
          check_database_queries(node)
        end

        def on_def(node)
          return unless in_glass_morph_component?

          check_parameter_naming(node) if node.method?(:initialize)
        end

        private

        def in_glass_morph_component?
          file_path = processed_source.file_path
          file_path.include?("app/components/glass_morph/") &&
            !file_path.include?("base_component.rb") &&
            !file_path.include?("concerns/") &&
            !file_path.end_with?(".rb~") &&
            !file_path.include?("spec/") &&
            !file_path.include?("styleguide/")
        end

        def check_frozen_string_literal(node)
          return if frozen_string_literal_comment_present?

          add_offense(node, message: MSG_NO_FROZEN_STRING_LITERAL) do |corrector|
            first_token = processed_source.tokens.first
            if first_token
              corrector.insert_before(first_token.pos, "# frozen_string_literal: true\n\n")
            end
          end
        end

        def frozen_string_literal_comment_present?
          processed_source.comments.any? do |comment|
            comment.text == "# frozen_string_literal: true"
          end
        end

        def check_base_class(node)
          parent_class = node.parent_class
          return unless parent_class

          base_class_name = parent_class.source

          valid_base_classes = [
            "Components::GlassMorph::BaseComponent",
            "::Components::GlassMorph::BaseComponent",
            "BaseComponent"
          ]

          return if valid_base_classes.include?(base_class_name)
          return if same_level_inheritance?(base_class_name)

          add_offense(
            parent_class,
            message: format(MSG_WRONG_BASE_CLASS, base_class: base_class_name)
          )
        end

        def same_level_inheritance?(base_class_name)
          file_path = processed_source.file_path

          if file_path.include?("/atoms/") && base_class_name.include?("::Atoms::")
            true
          elsif file_path.include?("/molecules/") && base_class_name.include?("::Molecules::")
            true
          elsif file_path.include?("/organisms/") && base_class_name.include?("::Organisms::")
            true
          else
            false
          end
        end

        def check_namespace(node)
          file_path = processed_source.file_path

          return if file_path.match?(%r{app/components/glass_morph/(atoms|molecules|organisms)/})
          return if file_path.match?(%r{app/components/glass_morph/[a-z_]+/[^/]+\.rb$})
          return if file_path.match?(%r{app/components/glass_morph/[^/]+\.rb$})

          add_offense(node.identifier, message: MSG_WRONG_NAMESPACE)
        end

        def check_required_methods(node)
          body = node.body
          return unless body

          methods = extract_method_names(body)

          add_offense(node.identifier, message: MSG_NO_VIEW_TEMPLATE) unless methods.include?(:view_template)
        end

        def extract_method_names(body)
          methods = []

          if body.def_type?
            methods << body.method_name
          elsif body.begin_type?
            body.children.each do |child|
              methods << child.method_name if child.def_type?
            end
          end

          methods
        end

        def check_parameter_naming(node)
          node.arguments.each do |arg|
            next unless arg.kwoptarg_type? || arg.kwarg_type?

            param_name = arg.children[0]

            if param_name == :additional_classes
              add_offense(arg, message: MSG_USE_CSS_CLASS) do |corrector|
                source = arg.source
                corrector.replace(arg, source.sub("additional_classes", "css_class"))
              end
            end
          end
        end

        def check_database_queries(node)
          node.each_descendant(:send) do |send_node|
            receiver = send_node.receiver
            method_name = send_node.method_name

            ar_only_query_methods = %i[
              find_by find_by! where includes joins
              exists? pluck sum average
              create create! update update! destroy destroy_all
            ]

            next unless ar_only_query_methods.include?(method_name)

            if receiver&.const_type?
              const_name = receiver.source
              next if const_name.start_with?("Components::")
              next if const_name.include?("DEMO_")
              next if const_name.include?("_CATEGORIES")
              next if const_name.include?("_COLORS")
              next if const_name.include?("_TYPES")
              next if const_name.end_with?("_CONSTANT")

              add_offense(send_node, message: MSG_DATABASE_QUERY)
            end
          end
        end
      end
    end
  end
end
