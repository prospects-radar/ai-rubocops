# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Suggests :aggregate_failures for spec blocks with multiple expectations.
      #
      # When an `it` block has 3 or more expectations, a single failure stops
      # execution and hides subsequent failures. Using :aggregate_failures runs
      # all expectations and reports all failures at once.
      #
      # @example
      #   # bad - 3 expectations without aggregate_failures
      #   it "validates the record" do
      #     expect(record.name).to eq("Foo")
      #     expect(record.status).to eq("active")
      #     expect(record.score).to be > 0
      #   end
      #
      #   # good - aggregate_failures enabled
      #   it "validates the record", :aggregate_failures do
      #     expect(record.name).to eq("Foo")
      #     expect(record.status).to eq("active")
      #     expect(record.score).to be > 0
      #   end
      #
      #   # good - using aggregate_failures block
      #   it "validates the record" do
      #     aggregate_failures do
      #       expect(record.name).to eq("Foo")
      #       expect(record.status).to eq("active")
      #       expect(record.score).to be > 0
      #     end
      #   end
      #
      class AggregateFailures < Base
        MSG = "Use `:aggregate_failures` when an `it` block has %<count>d expectations. " \
              "This reports all failures at once instead of stopping at the first."

        EXPECTATION_THRESHOLD = 3

        def_node_matcher :it_block?, <<~PATTERN
          (block (send nil? {:it :specify} ...) ...)
        PATTERN

        def on_block(node)
          return unless in_spec_file?
          return unless it_block?(node)
          return if has_aggregate_failures?(node)

          expectation_count = count_expectations(node)
          return if expectation_count < EXPECTATION_THRESHOLD

          add_offense(node.send_node,
            message: format(MSG, count: expectation_count))
        end

        private

        def in_spec_file?
          file_path = processed_source.file_path
          file_path.include?("spec/") && file_path.end_with?("_spec.rb")
        end

        def has_aggregate_failures?(node)
          send_node = node.send_node

          # Check for :aggregate_failures symbol arg
          send_node.arguments.any? do |arg|
            arg.sym_type? && arg.value == :aggregate_failures
          end || has_aggregate_failures_block?(node)
        end

        def has_aggregate_failures_block?(node)
          node.each_descendant(:block).any? do |block_node|
            block_node.send_node.method_name == :aggregate_failures
          end
        end

        def count_expectations(node)
          count = 0

          node.each_descendant(:send) do |send_node|
            count += 1 if send_node.method_name == :expect && send_node.receiver.nil?
          end

          count
        end
      end
    end
  end
end
