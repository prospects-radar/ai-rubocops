# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::NoInlineColorStyles, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/components/glass_morph/molecules/**/*.rb",
        "app/components/glass_morph/organisms/**/*.rb"
      ]
    }
  end

  let(:source_file_path) { "app/components/glass_morph/molecules/test_molecule.rb" }

  # ── style: with color property ──────────────────────────────────────────────

  it "registers an offense for inline style with CSS variable color" do
    expect_offense(<<~RUBY, source_file_path)
      Heading(level: 3, style: "color: var(--gm-teal-700); margin-bottom: 5px;") { title }
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline colour styles (`color:`). Add a BEM class to the component's CSS file and pass it via `class:` instead.
    RUBY
  end

  it "registers an offense for inline style with hex background" do
    expect_offense(<<~RUBY, source_file_path)
      Box(style: "background: #dc3545; padding: 8px;") { content }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline colour styles (`background:`). Add a BEM class to the component's CSS file and pass it via `class:` instead.
    RUBY
  end

  it "registers an offense for inline style with named color" do
    expect_offense(<<~RUBY, source_file_path)
      Span(style: "color: red;") { text }
           ^^^^^^^^^^^^^^^^^^^^^ Avoid inline colour styles (`color:`). Add a BEM class to the component's CSS file and pass it via `class:` instead.
    RUBY
  end

  it "registers an offense for inline style with background-color" do
    expect_offense(<<~RUBY, source_file_path)
      Box(style: "background-color: var(--gm-blue-overlay-8);") { content }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline colour styles (`background-color:`). Add a BEM class to the component's CSS file and pass it via `class:` instead.
    RUBY
  end

  it "registers an offense for inline style with kanban CSS variable color" do
    expect_offense(<<~RUBY, source_file_path)
      Heading(level: 3, weight: :semibold, style: "font-size: 1rem; color: var(--kanban-header-text); margin: 0;") { @title }
                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline colour styles (`color:`). Add a BEM class to the component's CSS file and pass it via `class:` instead.
    RUBY
  end

  it "does not register an offense for inline style without color properties" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Heading(level: 3, style: "margin: 0; line-height: 1.4;") { title }
    RUBY
  end

  it "does not register an offense for inline style with only layout properties" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Box(style: "width: 32px; height: 32px; min-width: 32px;") { content }
    RUBY
  end

  # ── named colour parameters ─────────────────────────────────────────────────

  it "registers an offense for icon_color with hex value" do
    expect_offense(<<~RUBY, source_file_path)
      ModalHeader(title: t("foo"), icon: "warn", icon_color: "#dc3545")
                                                 ^^^^^^^^^^^^^^^^^^^^^ Avoid hardcoded colour value in `icon_color:`. Use a symbol variant (e.g. `icon_variant: :danger`) or a BEM CSS class instead.
    RUBY
  end

  it "registers an offense for color param with CSS variable string" do
    expect_offense(<<~RUBY, source_file_path)
      render SliderComponent.new(color: "var(--gm-red-500)")
                                 ^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid hardcoded colour value in `color:`. Use a symbol variant (e.g. `icon_variant: :danger`) or a BEM CSS class instead.
    RUBY
  end

  it "registers an offense for color param with hex string" do
    expect_offense(<<~RUBY, source_file_path)
      render SliderComponent.new(color: "#ff4500")
                                 ^^^^^^^^^^^^^^^^ Avoid hardcoded colour value in `color:`. Use a symbol variant (e.g. `icon_variant: :danger`) or a BEM CSS class instead.
    RUBY
  end

  it "does not register an offense for color param with symbol variant" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Icon(name: "check", color: :success)
    RUBY
  end

  it "does not register an offense for icon_variant param" do
    expect_no_offenses(<<~RUBY, source_file_path)
      ModalHeader(title: t("foo"), icon: "warn", icon_variant: :danger)
    RUBY
  end

  # ── BEM class is the correct pattern ────────────────────────────────────────

  it "does not register an offense for color applied via BEM class" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Heading(level: 3, weight: :semibold, class: "stakeholder-name") { @stakeholder.full_name }
    RUBY
  end

  it "does not register an offense for color applied via event-title class" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Heading(level: 4, weight: :semibold, class: "event-title") { event[:title] }
    RUBY
  end
end
