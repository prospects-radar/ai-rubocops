# frozen_string_literal: true

require "open3"
require "fileutils"
require "spec_helper"

RSpec.describe "RuboCop::Cop::DesignSystem::NoRawSvgInComponents" do
  subject(:cop_output) do
    rubocop = Gem.bin_path("rubocop", "rubocop")
    cmd = [ RbConfig.ruby, rubocop, test_file_path,
            "--only", "DesignSystem/NoRawSvgInComponents", "--format", "simple" ]
    out, = Open3.capture2e({ "RUBYOPT" => nil }, *cmd)
    out
  end

  after do
    File.delete(test_file_path) if File.exist?(test_file_path)
  end

  before do
    FileUtils.mkdir_p(File.dirname(test_file_path))
    File.write(test_file_path, test_content)
  end

  context "when file is a molecule" do
    let(:test_file_path) { "app/components/glass_morph/molecules/test_svg_molecule.rb" }

    context "with an svg() Phlex call" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestMolecule
            def render_search_icon
              svg(viewBox: "0 0 16 16", fill: "currentColor") do
                path(d: "M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398")
              end
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawSvgInComponents")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with a raw SVG string" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestMolecule
            def render_icon
              raw '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M8 8"/></svg>'.html_safe
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawSvgInComponents")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with a raw SVG string without .html_safe" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestMolecule
            def render_icon
              raw '<svg viewBox="0 0 16 16"><path d="M8 8"/></svg>'
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawSvgInComponents")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with Icon() atom usage" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestMolecule
            def render_search_icon
              Icon(name: "search")
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end
  end

  context "when file is an organism" do
    let(:test_file_path) { "app/components/glass_morph/organisms/test_svg_organism.rb" }

    context "with an svg() Phlex call" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestOrganism
            def render_close_icon
              svg(width: "24", height: "24", viewBox: "0 0 24 24", fill: "none") do |s|
                s.line(x1: "18", y1: "6", x2: "6", y2: "18")
              end
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawSvgInComponents")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with Icon() atom usage" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestOrganism
            def render_close_icon
              Icon(name: "x-lg", size: :lg)
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end
  end

  context "when file is a view" do
    let(:test_file_path) { "app/views/glass_morph/companies/test_svg_view.rb" }

    context "with an svg() Phlex call" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestView
            def view_template
              svg(viewBox: "0 0 24 24") { path(d: "M5 12h14") }
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawSvgInComponents")
        expect(cop_output).to include("1 offense detected")
      end
    end
  end

  context "when file is an atom (not excluded unless listed in .rubocop.yml)" do
    let(:test_file_path) { "app/components/glass_morph/atoms/test_svg_atom.rb" }

    context "with an svg() Phlex call" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestAtom
            def render_svg_icon
              svg(xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 16 16") do
                path(d: "M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14z")
              end
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawSvgInComponents")
        expect(cop_output).to include("1 offense detected")
      end
    end
  end

  context "when file is outside glass_morph (not included)" do
    let(:test_file_path) { "app/components/shared/test_svg_component.rb" }

    context "with an svg() Phlex call" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def view_template
              svg(viewBox: "0 0 16 16") { path(d: "M8 8") }
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end
  end
end
