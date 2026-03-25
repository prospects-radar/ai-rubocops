# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Prefers let over instance variables in specs
      #
      # @example
      #   # bad
      #   describe "something" do
      #     before do
      #       @user = create(:user)
      #     end
      #   end
      #
      #   # good
      #   describe "something" do
      #     let(:user) { create(:user) }
      #   end
      #
      class PreferLetOverInstanceVariable < Base
        MSG = "Use `let(:variable)` instead of `@instance_variable` for test data"

        def_node_matcher :instance_variable_assignment?, <<~PATTERN
          (ivasgn $_variable ...)
        PATTERN

        def on_ivasgn(node)
          return unless in_spec_file?
          return unless inside_before_block?(node)

          instance_variable_assignment?(node) do |variable|
            add_offense(node)
          end
        end

        private

        def in_spec_file?
          processed_source.path.include?("spec/") &&
            processed_source.path.end_with?("_spec.rb")
        end

        def inside_before_block?(node)
          node.each_ancestor(:block).any? do |ancestor|
            ancestor.send_node.method_name == :before
          end
        end
      end
    end
  end
end
