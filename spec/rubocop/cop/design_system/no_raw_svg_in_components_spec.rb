# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::NoRawSvgInComponents, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/components/glass_morph/**/*.rb",
        "app/views/glass_morph/**/*.rb"
      ]
    }
  end

  context "when file is a molecule" do
    let(:source_file_path) { "app/components/glass_morph/molecules/test_svg_molecule.rb" }

    it "registers offense for svg() Phlex call" do
      expect_offense(<<~RUBY, source_file_path)
        class TestMolecule
          def render_search_icon
            svg(viewBox: "0 0 16 16", fill: "currentColor") do
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "...")[...]
              path(d: "M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398")
            end
          end
        end
      RUBY
    end

    it "registers offense for raw SVG string" do
      expect_offense(<<~RUBY, source_file_path)
        class TestMolecule
          def render_icon
            raw '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M8 8"/></svg>'.html_safe
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "...")[...]
          end
        end
      RUBY
    end

    it "does not register offense for Icon() atom usage" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestMolecule
          def render_search_icon
            Icon(name: "search")
          end
        end
      RUBY
    end
  end

  context "when file is an organism" do
    let(:source_file_path) { "app/components/glass_morph/organisms/test_svg_organism.rb" }

    it "registers offense for svg() Phlex call" do
      expect_offense(<<~RUBY, source_file_path)
        class TestOrganism
          def render_close_icon
            svg(width: "24", height: "24", viewBox: "0 0 24 24", fill: "none") do |s|
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "...")[...]
              s.line(x1: "18", y1: "6", x2: "6", y2: "18")
            end
          end
        end
      RUBY
    end

    it "does not register offense for Icon() atom usage" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestOrganism
          def render_close_icon
            Icon(name: "x-lg", size: :lg)
          end
        end
      RUBY
    end
  end

  context "when file is a view" do
    let(:source_file_path) { "app/views/glass_morph/companies/test_svg_view.rb" }

    it "registers offense for svg() Phlex call" do
      expect_offense(<<~RUBY, source_file_path)
        class TestView
          def view_template
            svg(viewBox: "0 0 24 24") { path(d: "M5 12h14") }
            ^^^^^^^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "...")[...]
          end
        end
      RUBY
    end
  end

  context "when file is outside glass_morph" do
    let(:source_file_path) { "app/components/shared/test_svg_component.rb" }

    it "does not register offense" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestComponent
          def view_template
            svg(viewBox: "0 0 16 16") { path(d: "M8 8") }
          end
        end
      RUBY
    end
  end
end
