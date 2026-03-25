# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces test ID presence and standardized naming convention for interactive GlassMorph components.
      #
      # This cop validates that:
      # 1. All organisms have root test IDs
      # 2. Interactive molecules have root test IDs
      # 3. Interactive atoms accept test_id parameter
      # 4. All test IDs follow standardized naming convention:
      #    - Kebab-case only (lowercase with hyphens)
      #    - Minimum 2 segments (context-component)
      #    - No generic single-word names
      #
      # @example
      #   # bad - organism missing test ID
      #   class ProspectCard < BaseComponent
      #     def view_template
      #       div(class: "card") { "Content" }
      #     end
      #   end
      #
      #   # bad - test ID is too generic
      #   class ProspectCard < BaseComponent
      #     def view_template
      #       div(**tid("card")) { "Content" }
      #     end
      #   end
      #
      #   # bad - test ID not kebab-case
      #   class ProspectCard < BaseComponent
      #     def view_template
      #       div(**tid("ProspectCard")) { "Content" }
      #     end
      #   end
      #
      #   # good - standardized test ID
      #   class ProspectCard < BaseComponent
      #     def view_template
      #       div(**root_attributes(base_class: "card"), **tid("prospect-card")) { "Content" }
      #     end
      #   end
      #
      class ComponentTestIdRequired < Base
        MSG_MISSING = "Interactive %<type>s must have a test ID using tid() helper"
        MSG_INVALID_NAMING = "Test ID '%<test_id>s' violates naming convention: %<violations>s"
        MSG_ATOM_NO_PARAM = "Interactive atom must accept test_id parameter in initialize"

        def on_class(node)
          return unless glass_morph_component?(node)

          component_type = determine_component_type(node)
          return unless component_type

          case component_type
          when :organism
            validate_organism(node)
          when :interactive_molecule
            validate_interactive_molecule(node)
          when :interactive_atom
            validate_interactive_atom(node)
          end
        end

        private

        def generic_names
          cop_config.fetch("GenericNames", %w[
            button link input select form div span container
            wrapper content body header footer card modal
            btn lnk txt box panel section
          ])
        end

        def interactive_molecule_patterns
          cop_config.fetch("InteractiveMoleculePatterns", %w[
            *_form.rb
            *_card.rb
            *_button*.rb
            nav_*.rb
            *_modal*.rb
            *_header.rb
            *_select.rb
            filter_*.rb
            *_navigation.rb
          ])
        end

        def interactive_atom_patterns
          cop_config.fetch("InteractiveAtomPatterns", %w[
            button.rb
            link*.rb
            *_input.rb
            select.rb
            checkbox.rb
            toggle_*.rb
          ])
        end

        def glass_morph_component?(node)
          file_path = processed_source.file_path
          file_path.include?("app/components/glass_morph/")
        end

        def determine_component_type(node)
          file_path = processed_source.file_path
          basename = File.basename(file_path)

          if file_path.include?("/organisms/")
            :organism
          elsif file_path.include?("/molecules/") && interactive_molecule?(basename)
            :interactive_molecule
          elsif file_path.include?("/atoms/") && interactive_atom?(basename)
            :interactive_atom
          end
        end

        def interactive_molecule?(basename)
          interactive_molecule_patterns.any? { |pattern| File.fnmatch?(pattern, basename) }
        end

        def interactive_atom?(basename)
          interactive_atom_patterns.any? { |pattern| File.fnmatch?(pattern, basename) }
        end

        def validate_organism(node)
          view_template = find_view_template_method(node)
          return unless view_template

          tid_calls = find_tid_calls(view_template)

          if tid_calls.empty?
            add_offense(node, message: format(MSG_MISSING, type: "organism"))
            return
          end

          # Validate naming convention for all tid() calls
          tid_calls.each do |tid_node|
            validate_test_id_naming(tid_node)
          end
        end

        def validate_interactive_molecule(node)
          view_template = find_view_template_method(node)
          return unless view_template

          tid_calls = find_tid_calls(view_template)

          if tid_calls.empty?
            add_offense(node, message: format(MSG_MISSING, type: "molecule"))
            return
          end

          # Validate naming convention
          tid_calls.each do |tid_node|
            validate_test_id_naming(tid_node)
          end
        end

        def validate_interactive_atom(node)
          initialize_method = find_initialize_method(node)
          return unless initialize_method

          # Check if initialize accepts test_id parameter
          params = initialize_method.arguments

          has_test_id_param = params.any? do |param|
            # Handle both kwarg (test_id:) and kwoptarg (test_id: nil)
            (param.kwarg_type? || param.kwoptarg_type?) && param.children.first == :test_id
          end

          unless has_test_id_param
            add_offense(initialize_method, message: MSG_ATOM_NO_PARAM)
          end
        end

        def find_view_template_method(class_node)
          class_node.each_descendant(:def).find do |def_node|
            def_node.method_name == :view_template
          end
        end

        def find_initialize_method(class_node)
          class_node.each_descendant(:def).find do |def_node|
            def_node.method_name == :initialize
          end
        end

        def find_tid_calls(node)
          tid_calls = []

          node.each_descendant(:send) do |send_node|
            tid_calls << send_node if send_node.method_name == :tid
          end

          tid_calls
        end

        def validate_test_id_naming(tid_node)
          # Extract test ID string from tid("test-id") call
          return unless tid_node.arguments.any?

          arg = tid_node.arguments.first
          return unless arg.str_type?

          test_id = arg.str_content
          violations = naming_violations(test_id)

          if violations.any?
            add_offense(
              tid_node,
              message: format(
                MSG_INVALID_NAMING,
                test_id: test_id,
                violations: violations.join(", ")
              )
            )
          end
        end

        def naming_violations(test_id)
          violations = []

          # Check kebab-case (lowercase with hyphens only)
          unless test_id.match?(/^[a-z][a-z0-9-]*$/)
            violations << "must be kebab-case (lowercase with hyphens only)"
          end

          # Check minimum segments
          segments = test_id.split("-")
          if segments.size < 2
            violations << "must have at least 2 segments (context-component)"
          end

          # Check for generic names
          if generic_names.include?(test_id)
            violations << "is too generic (must include context)"
          end

          violations
        end
      end
    end
  end
end
