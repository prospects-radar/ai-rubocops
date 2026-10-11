# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Flags an example that acts and checks, then acts and checks again.
      #
      # Each run of consecutive top-level statements holding an expectation is
      # one assert phase. Statements without one (setup, the action) separate
      # the runs. An example with more phases than `Max` is several tests
      # sharing one name, and the first failure hides the rest.
      #
      # Adapted from the multiple-phases smell in scrap4rb, which flags any
      # second phase. The default here allows two, because act-check-undo-check
      # is a common and readable shape for a toggle.
      #
      # @example Max: 2
      #   # bad
      #   it "walks the lifecycle" do
      #     subscription.activate!
      #     expect(subscription).to be_active
      #     subscription.pause!
      #     expect(subscription).to be_paused
      #     subscription.cancel!
      #     expect(subscription).to be_canceled
      #   end
      #
      #   # good - one example per transition
      #   it "pauses an active subscription" do
      #     subscription.pause!
      #     expect(subscription).to be_paused
      #   end
      #
      class MultiplePhases < Base
        MSG = "This example has %<phases>d act/assert phases (max %<max>d). " \
              "Split it so each phase is its own example."

        EXAMPLE_METHODS = %i[it specify example scenario].freeze
        EXPECTATION_METHODS = %i[expect is_expected are_expected expect_any_instance_of should should_not].freeze

        def on_block(node)
          return unless example?(node)

          phases = assert_phases(node.body)
          return if phases <= max

          add_offense(node.send_node, message: format(MSG, phases: phases, max: max))
        end
        alias on_numblock on_block

        private

        def example?(node)
          send_node = node.send_node
          send_node.receiver.nil? && EXAMPLE_METHODS.include?(send_node.method_name)
        end

        def assert_phases(body)
          statements(body)
            .map { |statement| expectation?(statement) }
            .chunk_while { |a, b| a == b }
            .count(&:first)
        end

        def statements(body)
          return [] if body.nil?

          body.begin_type? ? body.children : [ body ]
        end

        def expectation?(node)
          [ node, *node.each_descendant(:send) ].any? do |n|
            n.send_type? && n.receiver.nil? && EXPECTATION_METHODS.include?(n.method_name)
          end
        end

        def max
          cop_config.fetch("Max", 2)
        end
      end
    end
  end
end
