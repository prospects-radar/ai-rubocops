# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::NoInlineStyles, :config do
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

  # ── string values: inline CSS ───────────────────────────────────────────────

  it "registers an offense for a style: string" do
    expect_offense(<<~RUBY, source_file_path)
      div(style: "width: 40px; height: 40px;") { content }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline `style:` attributes. Use CSS classes or design tokens in stylesheets instead.
    RUBY
  end

  it "registers an offense for an interpolated style: string" do
    expect_offense(<<~RUBY, source_file_path)
      div(style: "width: \#{@width}px;") { content }
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline `style:` attributes. Use CSS classes or design tokens in stylesheets instead.
    RUBY
  end

  # ── symbol values: not CSS at all ───────────────────────────────────────────
  #
  # `style:` is inline CSS and nothing else, so a symbol there renders a literal
  # `style="bootstrap"` on the element. See issue #1065.

  it "registers an offense for a style: symbol" do
    expect_offense(<<~RUBY, source_file_path)
      Icon(name: "person", style: :bootstrap)
                           ^^^^^^^^^^^^^^^^^ Avoid inline `style:` attributes. Use CSS classes or design tokens in stylesheets instead.
    RUBY
  end

  # ── other keys named *_style are component parameters ───────────────────────

  it "does not register an offense for header_style:" do
    expect_no_offenses(<<~RUBY, source_file_path)
      GlassCard(variant: :section, header_style: :light) { content }
    RUBY
  end

  it "does not register an offense for a style: variable holding a runtime value" do
    expect_no_offenses(<<~RUBY, source_file_path)
      div(style: computed_style) { content }
    RUBY
  end

  # ── constants that embed CSS ────────────────────────────────────────────────

  it "registers an offense for a constant holding CSS" do
    expect_offense(<<~RUBY, source_file_path)
      CARD_STYLE = "box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Avoid inline `style:` attributes. Use CSS classes or design tokens in stylesheets instead.
    RUBY
  end

  it "does not register an offense for a constant holding a plain string" do
    expect_no_offenses(<<~RUBY, source_file_path)
      TITLE = "Prospects"
    RUBY
  end
end
