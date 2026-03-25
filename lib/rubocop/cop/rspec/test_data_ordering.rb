# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Detects specs that rely on implicit database ordering via .first/.last.
      #
      # Tests using .first or .last on collections without explicit ordering
      # are flaky because database ordering is not guaranteed across runs.
      #
      # @example
      #   # bad
      #   it "returns the latest record" do
      #     create(:record, name: "A")
      #     create(:record, name: "B")
      #     expect(Record.all.last.name).to eq("B")
      #   end
      #
      #   # good - explicit ordering
      #   it "returns the latest record" do
      #     create(:record, name: "A")
      #     create(:record, name: "B")
      #     expect(Record.order(:created_at).last.name).to eq("B")
      #   end
      #
      #   # good - using find_by or specific lookup
      #   it "creates a record" do
      #     create(:record, name: "A")
      #     expect(Record.find_by(name: "A")).to be_present
      #   end
      #
      class TestDataOrdering < Base
        MSG = "Avoid `.%<method>s` without explicit ordering in specs. " \
              "Database row order is not guaranteed. Use `.order(...)` first, " \
              "or use `find_by` for specific lookups."

        RESTRICT_ON_SEND = %i[first last].freeze

        def on_send(node)
          return unless in_spec_file?
          return unless %i[first last].include?(node.method_name)

          receiver = node.receiver
          return unless receiver

          # Skip if there's already an explicit order
          return if has_explicit_ordering?(receiver)

          # Skip if called on an array literal or local variable
          return if receiver.array_type?
          return if receiver.lvar_type?

          # Only flag when it looks like an ActiveRecord query
          return unless likely_ar_query?(receiver)

          add_offense(node.loc.selector,
            message: format(MSG, method: node.method_name))
        end

        private

        def in_spec_file?
          file_path = processed_source.file_path
          file_path.include?("spec/") && file_path.end_with?("_spec.rb")
        end

        def has_explicit_ordering?(node)
          return false unless node

          if node.send_type?
            return true if %i[order order_by reorder sort sort_by].include?(node.method_name)

            return has_explicit_ordering?(node.receiver)
          end

          false
        end

        def likely_ar_query?(node)
          return false unless node.send_type?

          ar_methods = %i[
            all where select joins includes preload eager_load
            group having distinct limit offset
            find_each find_in_batches
          ]

          return true if ar_methods.include?(node.method_name)

          # Check if receiver is a constant (Model.all.first)
          return true if node.receiver&.const_type?

          # Check receiver chain
          likely_ar_query?(node.receiver) if node.receiver&.send_type?
        end
      end
    end
  end
end
