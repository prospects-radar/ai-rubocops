# frozen_string_literal: true

module RuboCop
  module Cop
    module FactoryBot
      # Enforces consistent tenant handling in factories
      #
      # Prefer `association :account` over manual creation patterns
      #
      # @example
      #   # bad
      #   factory :company do
      #     account { Account.create!(name: "Test") }
      #   end
      #
      #   # good
      #   factory :company do
      #     association :account
      #   end
      #
      class ExplicitTenantHandling < Base
        MSG = "Use `association :account` instead of manual account creation in factories"

        def_node_search :manual_account_creation?, <<~PATTERN
          {
            (send (const nil? :Account) {:create :create!} ...)
            (block (send (const nil? :Account) :new) ...)
          }
        PATTERN

        def on_block(node)
          return unless in_factory_file?
          return unless factory_definition?(node)

          manual_account_creation?(node) do
            add_offense(node)
          end
        end

        private

        def in_factory_file?
          processed_source.path.include?("spec/factories/")
        end

        def factory_definition?(node)
          node.send_node.method_name == :factory
        end
      end
    end
  end
end
