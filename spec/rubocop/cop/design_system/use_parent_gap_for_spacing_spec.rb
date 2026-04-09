# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::UseParentGapForSpacing, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/components/**/*.rb",
        "app/views/**/*.rb",
        "spec/components/**/*.rb"
      ]
    }
  end

  let(:source_file_path) { "app/components/test_component.rb" }

  it "registers an offense for mt- on Span" do
    expect_offense(<<~RUBY, source_file_path)
      FlexRow(gap: :md) do
        Span(size: :sm, class: "mt-2px") { "text" }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use parent container's gap: parameter for spacing instead of[...]
      end
    RUBY
  end

  it "registers an offense for mb- on Icon" do
    expect_offense(<<~RUBY, source_file_path)
      FlexColumn do
        Icon(name: "check", class: "mb-075")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use parent container's gap: parameter for spacing instead of[...]
      end
    RUBY
  end

  it "registers an offense for ms- on Paragraph" do
    expect_offense(<<~RUBY, source_file_path)
      Paragraph(color: :muted, class: "ms-3") { "text" }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use parent container's gap: parameter for spacing instead of[...]
    RUBY
  end

  it "registers offense for multiple margin utilities on same component" do
    expect_offense(<<~RUBY, source_file_path)
      Span(size: :sm, class: "mt-2px mb-075") { "text" }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use parent container's gap: parameter for spacing instead of[...]
    RUBY
  end

  it "allows no margin utilities on components" do
    expect_no_offenses(<<~RUBY, source_file_path)
      FlexRow(gap: :md, align: :center) do
        Icon(name: "check")
        Span(size: :sm) { "text" }
      end
    RUBY
  end

  it "allows margin utilities on Box (layout container)" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Box(class: "mt-4") do
        Span(size: :sm) { "text" }
      end
    RUBY
  end

  it "allows margin utilities on FlexRow (layout container)" do
    expect_no_offenses(<<~RUBY, source_file_path)
      FlexRow(gap: :md, class: "mb-3") do
        Icon(name: "check")
      end
    RUBY
  end

  it "allows margin utilities on FlexColumn (layout container)" do
    expect_no_offenses(<<~RUBY, source_file_path)
      FlexColumn(gap: :lg, class: "mt-4 mb-2") do
        Paragraph { "text" }
      end
    RUBY
  end

  it "allows non-margin utilities on components" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Span(size: :sm, class: "text-truncate fw-medium") { "text" }
    RUBY
  end

  it "allows gap parameter on parent containers" do
    expect_no_offenses(<<~RUBY, source_file_path)
      FlexRow(gap: :xs) do
        Icon(name: "check")
        Span(size: :sm) { "text" }
      end
    RUBY
  end

  it "registers offense for me- on Label" do
    expect_offense(<<~RUBY, source_file_path)
      Label(text: "Name", class: "me-2")
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use parent container's gap: parameter for spacing instead of[...]
    RUBY
  end

  it "registers offense for m- on Button" do
    expect_offense(<<~RUBY, source_file_path)
      Button(text: "Click", class: "m-3")
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use parent container's gap: parameter for spacing instead of[...]
    RUBY
  end
end
