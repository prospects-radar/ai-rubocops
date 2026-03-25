# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Detects time-dependent test patterns that cause flaky specs.
      #
      # Specs that use Time.now, Date.today, or time comparisons without
      # freeze_time/travel_to are inherently flaky because they depend on
      # the system clock at execution time.
      #
      # @example
      #   # bad
      #   it "checks expiration" do
      #     record = create(:record, expires_at: Time.now + 1.hour)
      #     expect(record).to be_valid
      #   end
      #
      #   # bad
      #   it "checks creation date" do
      #     record = create(:record)
      #     expect(record.created_at.to_date).to eq(Date.today)
      #   end
      #
      #   # good
      #   it "checks expiration" do
      #     freeze_time do
      #       record = create(:record, expires_at: Time.current + 1.hour)
      #       expect(record).to be_valid
      #     end
      #   end
      #
      #   # good
      #   it "checks creation date" do
      #     travel_to(Date.new(2024, 1, 1)) do
      #       record = create(:record)
      #       expect(record.created_at.to_date).to eq(Date.new(2024, 1, 1))
      #     end
      #   end
      #
      class FlakyTimePatterns < Base
        MSG_TIME_NOW = "Use `Time.current` with `freeze_time` or `travel_to` instead of `Time.now` in specs. " \
                       "`Time.now` without freezing causes flaky tests."

        MSG_DATE_TODAY = "Use a fixed date with `travel_to` instead of `Date.today` in specs. " \
                         "`Date.today` without freezing causes flaky tests."

        RESTRICT_ON_SEND = %i[now today].freeze

        def on_send(node)
          return unless in_spec_file?

          check_time_now(node)
          check_date_today(node)
        end

        private

        def in_spec_file?
          file_path = processed_source.file_path
          file_path.include?("spec/") && file_path.end_with?("_spec.rb")
        end

        def check_time_now(node)
          return unless node.method_name == :now

          receiver = node.receiver
          return unless receiver&.const_type?
          return unless receiver.source == "Time"

          # Check if we're inside a freeze_time or travel_to block
          return if inside_time_freeze?(node)

          add_offense(node, message: MSG_TIME_NOW)
        end

        def check_date_today(node)
          return unless node.method_name == :today

          receiver = node.receiver
          return unless receiver&.const_type?
          return unless receiver.source == "Date"

          return if inside_time_freeze?(node)

          add_offense(node, message: MSG_DATE_TODAY)
        end

        def inside_time_freeze?(node)
          node.each_ancestor(:block).any? do |block_node|
            send_node = block_node.send_node
            next false unless send_node

            method_name = send_node.method_name
            %i[freeze_time travel_to travel].include?(method_name)
          end
        end
      end
    end
  end
end
