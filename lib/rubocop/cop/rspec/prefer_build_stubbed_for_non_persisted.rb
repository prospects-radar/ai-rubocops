# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Suggests using build_stubbed instead of create when persistence not needed
      #
      # build_stubbed creates in-memory objects 10-100x faster than create.
      # Use build_stubbed when the test only needs object attributes/associations
      # without actual database persistence.
      #
      # @example
      #   # bad (slow - database hit)
      #   let(:user) { create(:user) }
      #
      #   it "returns user name" do
      #     expect(service.format_name(user)).to eq("John Doe")
      #   end
      #
      #   # good (fast - in-memory)
      #   let(:user) { build_stubbed(:user) }
      #
      #   it "returns user name" do
      #     expect(service.format_name(user)).to eq("John Doe")
      #   end
      #
      # When to use create (persistence required):
      #   - Database queries (where, find, find_by, etc.)
      #   - Association queries through database
      #   - Callbacks that depend on persistence
      #   - Testing uniqueness validations
      #   - Controller/request specs with HTTP requests
      #   - Service specs that query the database
      #
      # When to use build_stubbed (no persistence needed):
      #   - Testing object attributes/methods
      #   - Passing objects to presenters/decorators
      #   - Component rendering with object data
      #   - Unit testing without database interaction
      #
      class PreferBuildStubbedForNonPersisted < Base
        # Detailed message with specific guidance
        MSG = "Consider `build_stubbed(:%<factory>s)` instead of `create` - " \
              "10-100x faster if no DB persistence needed. " \
              "Keep `create` if: queries, associations, callbacks, or uniqueness validation required."

        PERSISTENCE_INDICATORS = %i[
          save
          save!
          update
          update!
          update_attribute
          update_attributes
          update_column
          update_columns
          destroy
          destroy!
          delete
          reload
          touch
          increment
          increment!
          decrement
          decrement!
          toggle
          toggle!
        ].freeze

        # Query methods that require persistence
        QUERY_INDICATORS = %i[
          where
          find
          find_by
          find_by!
          find_or_create_by
          find_or_initialize_by
          first
          last
          all
          count
          exists?
          pluck
          ids
          select
          order
          limit
          offset
          joins
          includes
          eager_load
          preload
        ].freeze

        # Methods that require a persisted ID
        ID_DEPENDENT_METHODS = %i[
          id
          to_param
          to_key
          persisted?
        ].freeze

        def_node_matcher :create_in_let?, <<~PATTERN
          (block
            (send nil? :let (sym $_))
            (args)
            (send nil? :create (sym $_) ...)
          )
        PATTERN

        def_node_matcher :create_call?, <<~PATTERN
          (send nil? :create (sym $_) ...)
        PATTERN

        def_node_matcher :create_list_in_let?, <<~PATTERN
          (block
            (send nil? :let (sym $_))
            (args)
            (send nil? :create_list (sym $_) ...)
          )
        PATTERN

        def on_block(node)
          # Check for create in let
          create_in_let?(node) do |variable_name, factory_name|
            check_create_usage(node, variable_name, factory_name)
          end

          # Check for create_list in let
          create_list_in_let?(node) do |variable_name, factory_name|
            # create_list almost always needs persistence (for querying collections)
            # So we skip it - it's rarely safe to convert to build_stubbed_list
            nil
          end
        end

        private

        def check_create_usage(node, variable_name, factory_name)
          # Don't flag if there are clear persistence indicators in the spec
          return if uses_persistence?(node, variable_name)
          return if uses_queries?(node, variable_name)
          return if uses_id_dependent_methods?(node, variable_name)
          return if used_in_before_block_with_create?(node, variable_name)
          return if used_as_association_in_other_create?(node, variable_name)
          return if references_other_created_variables?(node)

          body = node.body
          return unless body

          # Check for simple create call
          create_call?(body) do |_|
            return if body.method?(:create!) # create! usually indicates intention to persist

            add_offense(body.loc.selector, message: format(MSG, factory: factory_name))
          end
        end

        def uses_persistence?(node, variable_name)
          spec_node = find_parent_spec(node)
          return false unless spec_node

          spec_node.each_descendant(:send) do |send_node|
            next unless send_node.receiver
            next unless references_variable?(send_node.receiver, variable_name)

            return true if PERSISTENCE_INDICATORS.include?(send_node.method_name)
          end

          false
        end

        def uses_queries?(node, variable_name)
          spec_node = find_parent_spec(node)
          return false unless spec_node

          # Check if the variable's class is used in queries
          spec_node.each_descendant(:send) do |send_node|
            # Check for Model.where, Model.find, etc.
            return true if QUERY_INDICATORS.include?(send_node.method_name)
          end

          false
        end

        def uses_id_dependent_methods?(node, variable_name)
          spec_node = find_parent_spec(node)
          return false unless spec_node

          spec_node.each_descendant(:send) do |send_node|
            next unless send_node.receiver
            next unless references_variable?(send_node.receiver, variable_name)

            return true if ID_DEPENDENT_METHODS.include?(send_node.method_name)
          end

          false
        end

        def used_in_before_block_with_create?(node, variable_name)
          spec_node = find_parent_spec(node)
          return false unless spec_node

          # Check if there's a before block that creates related records
          spec_node.each_descendant(:block) do |block_node|
            next unless block_node.send_node.method_name == :before

            # If before block has create calls, likely needs persistence
            block_node.each_descendant(:send) do |send_node|
              return true if send_node.method_name == :create || send_node.method_name == :create!
            end
          end

          false
        end

        def used_as_association_in_other_create?(node, variable_name)
          spec_node = find_parent_spec(node)
          return false unless spec_node

          # Check if the variable is passed as an association to another create call
          spec_node.each_descendant(:send) do |send_node|
            next unless %i[create create!].include?(send_node.method_name)

            # Check if any argument references our variable
            send_node.arguments.each do |arg|
              next unless arg.hash_type?

              arg.each_pair do |key, value|
                # Check if value references our variable
                if value.send_type? && value.method_name == variable_name
                  return true
                end
              end
            end
          end

          false
        end

        def references_other_created_variables?(node)
          # If this create call passes other variables as associations,
          # those variables likely need to be persisted, and so does this one
          body = node.body
          return false unless body

          # Get all variable names passed as keyword arguments to create
          body.arguments.each do |arg|
            next unless arg.hash_type?

            arg.each_pair do |_key, value|
              # If value is a method call (referencing another let variable)
              if value.send_type? && value.receiver.nil?
                referenced_var = value.method_name
                # Check if this referenced variable is defined with create
                return true if variable_defined_with_create?(node, referenced_var)
              end
            end
          end

          false
        end

        def variable_defined_with_create?(node, variable_name)
          # Find the root describe block and check if variable_name is defined with create
          root_spec = find_root_spec(node)
          return false unless root_spec

          root_spec.each_descendant(:block) do |block_node|
            # Check if this is a let block for our variable
            if block_node.send_node.method_name == :let
              let_name_arg = block_node.send_node.arguments.first
              next unless let_name_arg&.sym_type? && let_name_arg.value == variable_name

              # Check if the body is a create call
              body = block_node.body
              return true if body&.send_type? && %i[create create!].include?(body.method_name)
            end
          end

          false
        end

        def find_root_spec(node)
          # Find the outermost describe block
          root = nil
          node.each_ancestor(:block) do |ancestor|
            method_name = ancestor.send_node.method_name
            root = ancestor if %i[describe context].include?(method_name)
          end
          root
        end

        def references_variable?(receiver, variable_name)
          return true if receiver.send_type? && receiver.method_name == variable_name
          return true if receiver.lvar_type? && receiver.children.first == variable_name

          false
        end

        def find_parent_spec(node)
          node.each_ancestor(:block) do |ancestor|
            method_name = ancestor.send_node.method_name
            return ancestor if %i[describe context it].include?(method_name)
          end
          nil
        end
      end
    end
  end
end
