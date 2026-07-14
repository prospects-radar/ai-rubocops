# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Shared helpers for the ai-rubocops `let`-discipline cops
      # (MaxLetPerContext, NoLetOverrideInChildContext, NoActionInLet).
      #
      # Kept dependency-free: this gem does not require rubocop-rspec, so we
      # recognise example groups and `let` declarations by hand rather than
      # reusing RuboCop::RSpec::Language.
      module AiLetHelpers
        EXAMPLE_GROUP_METHODS = %i[
          describe context feature example_group
          shared_examples shared_examples_for shared_context
        ].freeze

        LET_METHODS = %i[let let!].freeze

        def in_spec_file?
          path = processed_source.path
          return false unless path

          path.include?("spec/") && path.end_with?("_spec.rb")
        end

        # A block whose send is `describe`/`context`/... (with or without an
        # `RSpec.` receiver).
        def example_group_block?(node)
          return false unless node.block_type? || node.numblock_type?

          send = node.send_node
          return false unless EXAMPLE_GROUP_METHODS.include?(send.method_name)

          recv = send.receiver
          recv.nil? || (recv.const_type? && recv.const_name == "RSpec")
        end

        # A `let`/`let!` call node (the send, not the block).
        def let_send?(send_node)
          return false unless send_node.send_type?
          return false unless LET_METHODS.include?(send_node.method_name)

          send_node.receiver.nil? && !let_name(send_node).nil?
        end

        # First-argument symbol name of a `let`, or nil for non-symbol forms.
        def let_name(send_node)
          arg = send_node.first_argument
          arg&.sym_type? ? arg.value : nil
        end

        # `let` sends declared DIRECTLY in a group body (not inside a nested
        # example group). Returns the send nodes.
        def direct_let_nodes(group_block)
          body = group_block.body
          return [] unless body

          statements = body.begin_type? ? body.children : [body]
          statements.filter_map { |stmt| let_send_of(stmt) }
        end

        # Given a statement node, return its `let` send if it is one
        # (handles both `let(:x) { }` blocks and bare `let(:x)`).
        def let_send_of(stmt)
          send = if stmt.block_type? || stmt.numblock_type?
                   stmt.send_node
                 elsif stmt.send_type?
                   stmt
                 end
          send if send && let_send?(send)
        end

        # Nearest enclosing example-group block, or nil.
        def enclosing_group(node)
          node.each_ancestor(:block, :numblock).find { |a| example_group_block?(a) }
        end

        # Report on the group's send (e.g. the `describe`/`context` keyword)
        # rather than the whole multi-line block.
        def group_offense_range(group_block)
          group_block.send_node.loc.selector
        end
      end
    end
  end
end
