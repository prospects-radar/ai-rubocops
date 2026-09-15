# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::SharedWork::NoProspectViewRead, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when usage behaviour reaches the list" do
    it "flags a query on the view record" do
      expect_offense(<<~RUBY)
        ProspectView.where(prospect_id: ids).exists?
        ^^^^^^^^^^^^ SharedWork/NoProspectViewRead: Looking is not attention (ADR-0082, ADR-0087). `ProspectView` is usage behaviour, and a shared work list decides on work: a task made, finished, or snoozed. If this one is deliberate, say so with `# shared-work-allowed: ADR-0082`.
      RUBY
    end

    it "flags the constant wherever it turns up" do
      expect_offense(<<~RUBY)
        views = prospect.association(:prospect_views).klass == ProspectView
                                                               ^^^^^^^^^^^^ SharedWork/NoProspectViewRead: Looking is not attention (ADR-0082, ADR-0087). `ProspectView` is usage behaviour, and a shared work list decides on work: a task made, finished, or snoozed. If this one is deliberate, say so with `# shared-work-allowed: ADR-0082`.
      RUBY
    end
  end

  context "when the list decides on work" do
    it "accepts the tasks a prospect has" do
      expect_no_offenses(<<~RUBY)
        Task.open_tasks.where.not(prospect_id: nil).distinct.pluck(:prospect_id)
      RUBY
    end

    it "accepts the constant named in a comment about why it is absent" do
      expect_no_offenses(<<~RUBY)
        # Looking is not attention (ADR-0082). A `ProspectView` recorded after the
        # streak began used to retire a prospect from this list permanently.
        def attended?(prospect_id, since, task_touches)
          task_touches[prospect_id].present?
        end
      RUBY
    end
  end

  context "when a decision allows it" do
    it "accepts a reference to an ADR on the line above" do
      expect_no_offenses(<<~RUBY)
        # shared-work-allowed: ADR-0082 — the snooze clock reads it, and that is the exception
        ProspectView.where(prospect_id: ids).maximum(:created_at)
      RUBY
    end
  end
end
