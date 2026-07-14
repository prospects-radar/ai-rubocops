# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Flags a `let` that redefines a name already declared in an ancestor
      # example group (override-across-nesting).
      #
      # Overriding a parent `let` in a child context is action-at-a-distance:
      # a reader must trace up through parent contexts to understand the
      # setup, and a change in the parent silently alters children. If any
      # child needs a different value, do NOT declare the `let` in the parent
      # at all - have each child declare its own.
      #
      # Report-only: the fix (remove the parent declaration and give each
      # sibling its own, or inline) cannot be applied mechanically.
      #
      # @example
      #   # bad - child overrides the parent's :user
      #   describe Thing do
      #     let(:user) { create(:user, admin: false) }
      #
      #     context "as admin" do
      #       let(:user) { create(:user, admin: true) }
      #     end
      #   end
      #
      #   # good - parent declares nothing; each context owns its data
      #   describe Thing do
      #     context "as member" do
      #       let(:user) { create(:user, admin: false) }
      #     end
      #
      #     context "as admin" do
      #       let(:user) { create(:user, admin: true) }
      #     end
      #   end
      class NoLetOverrideInChildContext < Base
        include RuboCop::Cop::RSpec::AiLetHelpers

        MSG = "`let(:%<name>s)` overrides a `let` from an enclosing context. " \
              "Declare it in each child context instead of overriding the parent."

        def on_send(node)
          return unless in_spec_file?
          return unless let_send?(node)

          name = let_name(node)
          own_group = enclosing_group(node)
          return unless own_group

          return unless ancestor_declares?(own_group, name)

          add_offense(node.loc.selector, message: format(MSG, name: name))
        end

        private

        # Does any example group ABOVE `own_group` declare a `let` of `name`?
        def ancestor_declares?(own_group, name)
          own_group.each_ancestor(:block, :numblock).any? do |ancestor|
            next false unless example_group_block?(ancestor)

            direct_let_nodes(ancestor).any? { |let| let_name(let) == name }
          end
        end
      end
    end
  end
end
