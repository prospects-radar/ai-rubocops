# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::ModalUsage, :config do
  subject(:cop) { described_class.new(config) }

  let(:gm_path) { "app/views/glass_morph/prospects/snooze_modal.rb" }

  it "flags raw `modal fade` markup in glass_morph files" do
    expect_offense(<<~RUBY, gm_path)
      div(class: "modal fade")
          ^^^^^^^^^^^^^^^^^^^ Use design system modal components (Modal, TurboModal, ConfirmationModal, DangerModal) instead of raw modal HTML. See app/components/glass_morph/organisms/ for available modals.
    RUBY
  end

  it "flags raw `modal-dialog` markup in glass_morph files" do
    expect_offense(<<~RUBY, gm_path)
      Box(class: "modal-dialog")
          ^^^^^^^^^^^^^^^^^^^^^ Use design system modal components (Modal, TurboModal, ConfirmationModal, DangerModal) instead of raw modal HTML. See app/components/glass_morph/organisms/ for available modals.
    RUBY
  end

  it "does NOT flag `modal-content` — the standard body slot inside a TurboModal/Modal" do
    expect_no_offenses(<<~RUBY, gm_path)
      Box(class: "modal-content") do
        plain "body"
      end
    RUBY
  end

  it "does not flag plain non-modal classes" do
    expect_no_offenses(<<~RUBY, gm_path)
      Box(class: "row-avatar-container")
    RUBY
  end

  it "ignores files outside glass_morph" do
    expect_no_offenses(<<~RUBY, "app/views/other/thing.rb")
      div(class: "modal-dialog")
    RUBY
  end

  it "ignores modal-body implementation paths (turbo_confirm_dialog)" do
    expect_no_offenses(<<~RUBY, "app/components/glass_morph/organisms/turbo_confirm_dialog.rb")
      div(class: "modal-dialog")
    RUBY
  end
end
