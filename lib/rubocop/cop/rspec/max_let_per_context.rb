# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Flags example groups declaring more than `Max` `let`/`let!` directly.
      #
      # Too many memoized helpers in one context hide test dependencies,
      # obscure what data is created, and encourage tight coupling. Keep 1-3
      # per context; the hard ceiling is `Max` (default 5). Only `let`s
      # declared DIRECTLY in the group count - nested contexts are counted
      # against their own group.
      #
      # This cop is report-only. There is no safe mechanical autocorrect:
      # reducing the count means pushing declarations into narrower child
      # contexts or inlining values, which requires human judgement.
      #
      # @example Max: 5 (default)
      #   # bad - 6 lets in one context
      #   describe Thing do
      #     let(:a) { 1 }
      #     let(:b) { 2 }
      #     let(:c) { 3 }
      #     let(:d) { 4 }
      #     let(:e) { 5 }
      #     let(:f) { 6 }
      #   end
      #
      #   # good - push some down to the contexts that need them
      #   describe Thing do
      #     let(:a) { 1 }
      #     let(:b) { 2 }
      #
      #     context "when f matters" do
      #       let(:f) { 6 }
      #     end
      #   end
      class MaxLetPerContext < Base
        include RuboCop::Cop::RSpec::AiLetHelpers

        MSG = "Context declares %<count>d `let`/`let!` (max %<max>d). " \
              "Aim for 1-3; push extras into the narrower contexts that use them."

        def on_block(node)
          return unless in_spec_file?
          return unless example_group_block?(node)

          count = direct_let_nodes(node).size
          return if count <= max_lets

          add_offense(
            group_offense_range(node),
            message: format(MSG, count: count, max: max_lets)
          )
        end
        alias on_numblock on_block

        private

        def max_lets
          Integer(cop_config.fetch("Max", 5))
        end
      end
    end
  end
end
