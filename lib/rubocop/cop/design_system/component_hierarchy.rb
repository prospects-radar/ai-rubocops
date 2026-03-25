# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces proper NewUI component hierarchy following atomic design principles.
      #
      # Atoms are the smallest building blocks and cannot use Molecules or Organisms.
      # Molecules can use Atoms but not other Molecules or Organisms.
      # Organisms can use Atoms and Molecules but not other Organisms.
      #
      # This ensures proper component composition and prevents circular dependencies.
      #
      # Note: Same-level inheritance (e.g., Molecule inheriting from Molecule) is allowed
      # for backward compatibility wrappers and aliases.
      #
      # @example
      #   # bad - in app/components/glass_morph/atoms/button.rb
      #   render Components::GlassMorph::Molecules::Card.new  # Atoms cannot use Molecules
      #   render Components::GlassMorph::Organisms::Modal.new  # Atoms cannot use Organisms
      #
      #   # bad - in app/components/glass_morph/molecules/card.rb
      #   render Components::GlassMorph::Molecules::Form.new  # Molecules cannot use other Molecules
      #   render Components::GlassMorph::Organisms::Modal.new  # Molecules cannot use Organisms
      #
      #   # bad - in app/components/glass_morph/organisms/modal.rb
      #   render Components::GlassMorph::Organisms::Sidebar.new  # Organisms cannot use other Organisms
      #
      #   # good - in app/components/glass_morph/atoms/button.rb
      #   # (no component rendering, only HTML)
      #
      #   # good - in app/components/glass_morph/molecules/card.rb
      #   render Components::GlassMorph::Atoms::Badge.new
      #   render Components::GlassMorph::Atoms::Icon.new
      #
      #   # good - in app/components/glass_morph/organisms/modal.rb
      #   render Components::GlassMorph::Atoms::Button.new
      #   render Components::GlassMorph::Molecules::Card.new
      #
      class ComponentHierarchy < Base
        MSG_ATOM_VIOLATION = "Atoms cannot use Molecules or Organisms. " \
                             "Atoms should only render basic HTML elements."

        MSG_MOLECULE_VIOLATION = "Molecules can only use Atoms, not other Molecules or Organisms. " \
                                 "Found usage of %<component_type>s."

        MSG_ORGANISM_VIOLATION = "Organisms can use Atoms and Molecules, but not other Organisms. " \
                                 "Found usage of Organism."

        def on_const(node)
          return unless in_glass_morph_component?

          const_name = node.source
          return unless const_name.start_with?("Components::GlassMorph::")

          # Skip inheritance checks (class definitions) - allow same-level inheritance for wrappers/aliases
          return if inheritance_context?(node)

          # Skip intermediate namespace constants that are part of a longer qualified name
          # (e.g., skip "TaskModal" when it's part of "TaskModal::DynamicField")
          return if intermediate_namespace?(node)

          current_level = component_level_from_path
          referenced_level = component_level_from_const(const_name)

          check_hierarchy_violation(node, current_level, referenced_level)
        end

        private

        def in_glass_morph_component?
          file_path = processed_source.file_path
          file_path.match?(%r{app/components/glass_morph/(atoms|molecules|organisms)/}) &&
            !file_path.include?("styleguide/")
        end

        def inheritance_context?(node)
          parent = node.parent
          return false unless parent

          parent.class_type? && parent.parent_class == node
        end

        def intermediate_namespace?(node)
          parent = node.parent
          return false unless parent

          parent.const_type?
        end

        def component_level_from_path
          path = processed_source.file_path
          return :atom if path.include?("/atoms/")
          return :molecule if path.include?("/molecules/")
          return :organism if path.include?("/organisms/")

          nil
        end

        def component_level_from_const(const_name)
          return :atom if const_name.include?("::Atoms::")
          return :molecule if const_name.include?("::Molecules::")
          return :organism if const_name.include?("::Organisms::")

          nil
        end

        def check_hierarchy_violation(node, current_level, referenced_level)
          const_name = node.source

          case current_level
          when :atom
            check_atom_violation(node, referenced_level)
          when :molecule
            check_molecule_violation(node, referenced_level, const_name)
          when :organism
            check_organism_violation(node, referenced_level, const_name)
          end
        end

        def check_atom_violation(node, referenced_level)
          return if referenced_level.nil?

          if referenced_level == :molecule || referenced_level == :organism
            add_offense(node, message: MSG_ATOM_VIOLATION)
          end
        end

        def check_molecule_violation(node, referenced_level, const_name)
          return if referenced_level.nil?

          if referenced_level == :molecule
            return if same_subnamespace?(const_name)
            add_offense(node, message: format(MSG_MOLECULE_VIOLATION, component_type: "Molecule"))
          elsif referenced_level == :organism
            add_offense(node, message: format(MSG_MOLECULE_VIOLATION, component_type: "Organism"))
          end
        end

        def check_organism_violation(node, referenced_level, const_name)
          return if referenced_level.nil?

          if referenced_level == :organism
            return if same_subnamespace?(const_name)
            add_offense(node, message: MSG_ORGANISM_VIOLATION)
          end
        end

        def same_subnamespace?(const_name)
          file_path = processed_source.file_path

          file_subns = file_path[%r{/(atoms|molecules|organisms)/([^/]+)/}, 2]
          return false unless file_subns

          const_parts = const_name.split("::")
          const_subns = nil

          level_index = const_parts.index { |p| %w[Atoms Molecules Organisms].include?(p) }
          if level_index && level_index < const_parts.length - 2
            const_subns = const_parts[level_index + 1]
          end

          return false unless const_subns

          const_subns_snake = const_subns.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                                         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                                         .downcase

          file_subns == const_subns_snake
        end
      end
    end
  end
end
