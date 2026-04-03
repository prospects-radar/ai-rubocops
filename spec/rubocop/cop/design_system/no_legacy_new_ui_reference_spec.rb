# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::NoLegacyNewUiReference, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/components/**/*.rb",
        "app/views/**/*.rb",
        "app/layouts/**/*.rb",
        "spec/components/**/*.rb"
      ]
    }
  end

  let(:source_file_path) { "app/components/glass_morph/test_component.rb" }

  it "registers an offense for legacy namespace constants" do
    offenses = inspect_source(<<~RUBY, source_file_path)
      class TestComponent < Components::NewUi::BaseComponent
      end
    RUBY

    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to eq(described_class::MSG)
  end

  it "registers an offense for legacy path strings" do
    offenses = inspect_source(<<~RUBY, source_file_path)
      class TestComponent
        LEGACY_PATH = "app/components/new_ui/molecules/region_select.rb"
      end
    RUBY

    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to eq(described_class::MSG)
  end

  it "allows GlassMorph references" do
    expect_no_offenses(<<~RUBY, source_file_path)
      class TestComponent < Components::GlassMorph::BaseComponent
        DOC_PATH = "app/components/glass_morph/molecules/region_select.rb"
      end
    RUBY
  end
end
