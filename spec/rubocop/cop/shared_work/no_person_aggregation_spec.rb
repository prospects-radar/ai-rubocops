# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::SharedWork::NoPersonAggregation, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when the list is folded per person" do
    it "flags a group_by on the assignee" do
      expect_offense(<<~RUBY)
        tasks.group_by(&:assigned_to_id)
              ^^^^^^^^ SharedWork/NoPersonAggregation: `group_by` keyed on `assigned_to_id` turns a shared work list into a measurement per person (ADR-0063, ADR-0087). Order and group by the work — how late it is, which prospect it is about. If this one is deliberate, say so with `# shared-work-allowed: ADR-0087`.
      RUBY
    end

    it "reads the block body, not only the arguments" do
      expect_offense(<<~RUBY)
        stalled.sort_by { |task| task.assigned_to.name }
                ^^^^^^^ SharedWork/NoPersonAggregation: `sort_by` keyed on `assigned_to` turns a shared work list into a measurement per person (ADR-0063, ADR-0087). Order and group by the work — how late it is, which prospect it is about. If this one is deliberate, say so with `# shared-work-allowed: ADR-0087`.
      RUBY
    end

    it "flags an order on the column" do
      expect_offense(<<~RUBY)
        Task.open_tasks.order(:created_by_id)
                        ^^^^^ SharedWork/NoPersonAggregation: `order` keyed on `created_by_id` turns a shared work list into a measurement per person (ADR-0063, ADR-0087). Order and group by the work — how late it is, which prospect it is about. If this one is deliberate, say so with `# shared-work-allowed: ADR-0087`.
      RUBY
    end

    it "flags a count grouped on a person column written as a string" do
      expect_offense(<<~RUBY)
        Task.group("tasks.assigned_to_id").count
             ^^^^^ SharedWork/NoPersonAggregation: `group` keyed on `assigned_to_id` turns a shared work list into a measurement per person (ADR-0063, ADR-0087). Order and group by the work — how late it is, which prospect it is about. If this one is deliberate, say so with `# shared-work-allowed: ADR-0087`.
      RUBY
    end
  end

  context "when the aggregation is about the work" do
    it "accepts an ordering by how late the work is" do
      expect_no_offenses(<<~RUBY)
        stalled.sort_by(&:stalled_since)
      RUBY
    end

    it "accepts a grouping by prospect" do
      expect_no_offenses(<<~RUBY)
        rows.group_by(&:prospect_id)
      RUBY
    end

    it "accepts an association load, which aggregates nothing" do
      expect_no_offenses(<<~RUBY)
        Task.open_tasks.includes(:assigned_to, prospect: [ :product ])
      RUBY
    end

    it "accepts naming the column without reporting on it" do
      expect_no_offenses(<<~RUBY)
        Task.open_tasks.pluck(:assigned_to_id)
      RUBY
    end
  end

  context "when a decision allows it" do
    it "accepts a reference to an ADR on the line above" do
      expect_no_offenses(<<~RUBY)
        # shared-work-allowed: ADR-0087 — the works council asked for this one
        tasks.group_by(&:assigned_to_id)
      RUBY
    end

    it "accepts a ticket number on the same line" do
      expect_no_offenses(<<~RUBY)
        tasks.group_by(&:assigned_to_id) # shared-work-allowed: #1101
      RUBY
    end

    it "still flags a comment that names no decision" do
      expect_offense(<<~RUBY)
        # this is fine, honestly
        tasks.group_by(&:assigned_to_id)
              ^^^^^^^^ SharedWork/NoPersonAggregation: `group_by` keyed on `assigned_to_id` turns a shared work list into a measurement per person (ADR-0063, ADR-0087). Order and group by the work — how late it is, which prospect it is about. If this one is deliberate, say so with `# shared-work-allowed: ADR-0087`.
      RUBY
    end
  end
end
