# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Flags an example that stubs or fakes more collaborators than `Max`.
      #
      # Counted inside the example body: each `receive`-family matcher (one per
      # `allow(...).to receive` or `expect(...).to receive`), each test double,
      # and each `stub_const` or `stub_request`. Past a handful, the example
      # mostly checks that the code calls what the stubs say it calls, and it
      # breaks on every refactor that keeps the behaviour.
      #
      # Stubs in a `before` block are not counted: they are shared by the
      # group, and MaxLetPerContext already watches group setup.
      #
      # Adapted from the high-mocking smell in scrap4rb, which uses the same
      # default of 3.
      #
      # @example Max: 3
      #   # bad
      #   it "syncs the order" do
      #     allow(Gateway).to receive(:fetch).and_return(order)
      #     allow(Mapper).to receive(:call).and_return(payload)
      #     allow(Client).to receive(:post).and_return(response)
      #     allow(Notifier).to receive(:notify)
      #
      #     described_class.call(order.id)
      #
      #     expect(Client).to have_received(:post).with(payload)
      #   end
      #
      class MaxStubsPerExample < Base
        MSG = "This example sets up %<count>d stubs or doubles (max %<max>d). " \
              "Test the collaborators for real, or move shared stubs into a context."

        EXAMPLE_METHODS = %i[it specify example scenario].freeze
        STUB_METHODS = %i[
          receive receive_messages receive_message_chain
          double instance_double class_double object_double
          spy instance_spy class_spy object_spy
          stub_const stub_request
        ].freeze

        def on_block(node)
          return unless example?(node)
          return if node.body.nil?

          count = stub_count(node.body)
          return if count <= max

          add_offense(node.send_node, message: format(MSG, count: count, max: max))
        end
        alias on_numblock on_block

        private

        def example?(node)
          send_node = node.send_node
          send_node.receiver.nil? && EXAMPLE_METHODS.include?(send_node.method_name)
        end

        def stub_count(body)
          [ body, *body.each_descendant(:send) ].count do |n|
            n.send_type? && n.receiver.nil? && STUB_METHODS.include?(n.method_name)
          end
        end

        def max
          cop_config.fetch("Max", 3)
        end
      end
    end
  end
end
