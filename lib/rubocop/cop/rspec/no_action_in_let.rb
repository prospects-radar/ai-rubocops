# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Flags a plain `let` whose body performs a side-effecting ACTION
      # rather than defining a value.
      #
      # `let` conveys a domain-object definition (a noun); `before` describes
      # actions that happen before each example (a verb). Because `let` is
      # lazily evaluated, hiding side effects - sending mail, enqueuing jobs,
      # running the subject, issuing HTTP requests - inside it makes the
      # timing of those effects unclear. Use `before` (for several examples)
      # or inline the call (for one).
      #
      # `let!` is exempt: eager evaluation is its purpose, so factory-style
      # setup there is idiomatic. Factory calls (`create`/`build`) are values,
      # not actions, and are never flagged.
      #
      # Report-only: moving a `let` body to `before` or inlining it changes
      # evaluation timing and cannot be autocorrected safely.
      #
      # @example
      #   # bad - runs the subject inside a let
      #   let(:result) { described_class.new(params).call }
      #
      #   # bad - side effect hidden behind lazy eval
      #   let(:sent) { UserMailer.welcome(user).deliver_now }
      #
      #   # good - value definition
      #   let(:params) { { id: user.id } }
      #
      #   # good - action in before
      #   before { described_class.new(params).call }
      class NoActionInLet < Base
        include RuboCop::Cop::RSpec::AiLetHelpers

        MSG = "`let(:%<name>s)` performs an action (`%<action>s`). `let` is for " \
              "values; move the action to a `before` block or inline it."

        DEFAULT_ACTION_METHODS = %w[
          deliver_now deliver_later
          perform perform_now perform_later perform_enqueued_jobs
          sign_in sign_out visit
          post get patch put delete
          call
        ].freeze

        def on_block(node)
          return unless in_spec_file?

          send = node.send_node
          return unless send.method_name == :let && send.receiver.nil?
          return if let_name(send).nil?

          action = action_call(node)
          return unless action

          add_offense(
            send.loc.selector,
            message: format(MSG, name: let_name(send), action: action)
          )
        end
        alias on_numblock on_block

        private

        # First action send executed directly by the let block (not one nested
        # inside a lambda/proc that only DEFINES behaviour). Returns the method
        # name string or nil.
        def action_call(let_block)
          body = let_block.body
          return nil unless body

          body.each_node(:send).find do |send|
            action_methods.include?(send.method_name.to_s) &&
              directly_in?(send, let_block)
          end&.method_name&.to_s
        end

        # True when no block/numblock sits between `node` and `let_block`
        # (i.e. the send actually runs when the let is resolved).
        def directly_in?(node, let_block)
          node.each_ancestor(:block, :numblock).each do |anc|
            return true if anc.equal?(let_block)
            return false # a nested block came first
          end
          false
        end

        def action_methods
          Array(cop_config.fetch("ActionMethods", DEFAULT_ACTION_METHODS))
        end
      end
    end
  end
end
