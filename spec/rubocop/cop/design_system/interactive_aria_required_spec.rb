# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::DesignSystem::InteractiveAriaRequired, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in GlassMorph component" do
    let(:source_file_path) { "app/components/glass_morph/organisms/toolbar.rb" }

    it "registers offense for icon-only button without aria_label" do
      expect_offense(<<~RUBY, source_file_path)
        render Components::GlassMorph::Atoms::Button.new(
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ DesignSystem/InteractiveAriaRequired: Interactive component `Button` with icon-only display must include `aria_label:` or `aria:` for screen reader accessibility.
          variant: :ghost,
          icon: "trash"
        )
      RUBY
    end

    it "does not register offense for button with aria_label" do
      expect_no_offenses(<<~RUBY, source_file_path)
        render Components::GlassMorph::Atoms::Button.new(
          variant: :ghost,
          icon: "trash",
          aria_label: "Delete item"
        )
      RUBY
    end

    it "does not register offense for button with label text" do
      expect_no_offenses(<<~RUBY, source_file_path)
        render Components::GlassMorph::Atoms::Button.new(
          variant: :primary,
          icon: "plus",
          label: "Add new"
        )
      RUBY
    end

    it "does not register offense for button without icon" do
      expect_no_offenses(<<~RUBY, source_file_path)
        render Components::GlassMorph::Atoms::Button.new(
          variant: :primary,
          label: "Save"
        )
      RUBY
    end

    it "does not register offense for button with title attribute" do
      expect_no_offenses(<<~RUBY, source_file_path)
        render Components::GlassMorph::Atoms::Button.new(
          variant: :ghost,
          icon: "trash",
          title: "Delete"
        )
      RUBY
    end
  end

  context "when not in GlassMorph file" do
    let(:source_file_path) { "app/services/my_service.rb" }

    it "does not check non-component files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        render Components::GlassMorph::Atoms::Button.new(
          variant: :ghost,
          icon: "trash"
        )
      RUBY
    end
  end
end
