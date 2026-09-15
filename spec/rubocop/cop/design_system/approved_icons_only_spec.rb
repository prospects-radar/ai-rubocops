# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::ApprovedIconsOnly, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => ["app/**/*.rb", "packs/**/*.rb"],
      "ApprovedIcons" => %w[buildings person check-lg]
    }
  end

  let(:source_file_path) { "app/components/glass_morph/molecules/test_molecule.rb" }

  it "registers an offense for a name outside the approved set" do
    expect_offense(<<~RUBY, source_file_path)
      Icon(name: "sparkles", size: :sm)
                 ^^^^^^^^^^ `sparkles` is not in the approved icon set. Pick an approved name, or add it to APPROVED_ICONS, the design-system skill and icon_map.css together.
    RUBY
  end

  it "registers an offense for the long render form" do
    expect_offense(<<~RUBY, source_file_path)
      render Components::GlassMorph::Atoms::Icon.new(name: "sparkles")
                                                           ^^^^^^^^^^ `sparkles` is not in the approved icon set. Pick an approved name, or add it to APPROVED_ICONS, the design-system skill and icon_map.css together.
    RUBY
  end

  it "does not register an offense for an approved name" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Icon(name: "buildings", size: :lg)
    RUBY
  end

  # A runtime name is the documented escape hatch: the cop cannot read it, and
  # the atom renders whatever icon_map.css has a rule for.
  it "does not register an offense for a computed name" do
    expect_no_offenses(<<~RUBY, source_file_path)
      Icon(name: icon_for(@status))
      Icon(name: opt[:icon])
      Icon(name: name.to_s)
    RUBY
  end

  it "ignores a name: pair on a component that is not an Icon" do
    expect_no_offenses(<<~RUBY, source_file_path)
      FormGroup(name: "prospect[title]", label: t(".title"))
    RUBY
  end

  context "when the approved set is read from a file" do
    let(:cop_config) do
      {
        "Include" => ["app/**/*.rb"],
        "ApprovedIconsFile" => fixture_path,
        "ApprovedIconsConstant" => "APPROVED_ICONS"
      }
    end

    let(:fixture_path) { "tmp/approved_icons_fixture.rb" }

    before do
      FileUtils.mkdir_p(File.dirname(fixture_path))
      File.write(fixture_path, <<~RUBY)
        class BaseComponent
          APPROVED_ICONS = %w[
            buildings person
            check-lg
          ].freeze
        end
      RUBY
    end

    after { FileUtils.rm_f(fixture_path) }

    it "reads the names out of the constant" do
      expect_offense(<<~RUBY, source_file_path)
        Icon(name: "sparkles")
                   ^^^^^^^^^^ `sparkles` is not in the approved icon set. Pick an approved name, or add it to APPROVED_ICONS, the design-system skill and icon_map.css together.
      RUBY
    end

    it "accepts a name from the constant" do
      expect_no_offenses(<<~RUBY, source_file_path)
        Icon(name: "check-lg")
      RUBY
    end
  end

  context "when no approved set is configured" do
    let(:cop_config) { { "Include" => ["app/**/*.rb"] } }

    it "stays silent rather than flagging every icon" do
      expect_no_offenses(<<~RUBY, source_file_path)
        Icon(name: "sparkles")
      RUBY
    end
  end
end
