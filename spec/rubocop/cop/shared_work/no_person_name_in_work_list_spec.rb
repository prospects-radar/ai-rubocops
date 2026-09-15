# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::SharedWork::NoPersonNameInWorkList, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when a row names the colleague holding the work" do
    it "flags a name read off the assignee" do
      expect_offense(<<~RUBY)
        task.assigned_to.full_name
                         ^^^^^^^^^ SharedWork/NoPersonNameInWorkList: A shared work list says work is held, never by whom (ADR-0063, ADR-0087). `assigned_to.full_name` puts a colleague's name on the row. Name the work instead, or say why this one is different with `# shared-work-allowed: ADR-0087`.
      RUBY
    end

    it "flags an email behind a safe navigation" do
      expect_offense(<<~RUBY)
        stalled.assignee&.email
                          ^^^^^ SharedWork/NoPersonNameInWorkList: A shared work list says work is held, never by whom (ADR-0063, ADR-0087). `assignee.email` puts a colleague's name on the row. Name the work instead, or say why this one is different with `# shared-work-allowed: ADR-0087`.
      RUBY
    end

    it "flags the creator of the task" do
      expect_offense(<<~RUBY)
        t("row.made_by", who: created_by.name)
                                         ^^^^ SharedWork/NoPersonNameInWorkList: A shared work list says work is held, never by whom (ADR-0063, ADR-0087). `created_by.name` puts a colleague's name on the row. Name the work instead, or say why this one is different with `# shared-work-allowed: ADR-0087`.
      RUBY
    end

    it "flags an instance variable holding the person" do
      expect_offense(<<~RUBY)
        @assignee.display_name
                  ^^^^^^^^^^^^ SharedWork/NoPersonNameInWorkList: A shared work list says work is held, never by whom (ADR-0063, ADR-0087). `assignee.display_name` puts a colleague's name on the row. Name the work instead, or say why this one is different with `# shared-work-allowed: ADR-0087`.
      RUBY
    end
  end

  context "when the row names the work" do
    it "accepts the label that says a task is held" do
      expect_no_offenses(<<~RUBY)
        t("unattended_opportunities.row.assigned")
      RUBY
    end

    it "accepts the rule that raised the task" do
      expect_no_offenses(<<~RUBY)
        task.action_rule&.name
      RUBY
    end

    it "accepts a prospect company's name" do
      expect_no_offenses(<<~RUBY)
        prospect.prospect_company.name
      RUBY
    end

    it "leaves the reader's own name alone" do
      expect_no_offenses(<<~RUBY)
        current_user.full_name
      RUBY
    end
  end

  context "when a decision allows it" do
    it "accepts a reference to an ADR on the line above" do
      expect_no_offenses(<<~RUBY)
        # shared-work-allowed: ADR-0087 — the assignment control names who it assigns to
        task.assigned_to.full_name
      RUBY
    end
  end
end
