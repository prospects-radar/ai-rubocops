# frozen_string_literal: true

require "open3"
require "fileutils"
require "spec_helper"

RSpec.describe "RuboCop::Cop::DesignSystem::NoRawBiIconClasses" do
  subject(:cop_output) do
    rubocop = Gem.bin_path("rubocop", "rubocop")
    cmd = [ RbConfig.ruby, rubocop, test_file_path,
           "--only", "DesignSystem/NoRawBiIconClasses", "--format", "simple" ]
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

  context "when file is in app/views/glass_morph" do
    let(:test_file_path) { "app/views/glass_morph/test_view.rb" }

    context "with a plain bi bi-* class" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestView
            def view_template
              i(class: "bi bi-chevron-right")
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawBiIconClasses")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with bi bi-* mixed into other classes" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestView
            def view_template
              div(class: "d-flex bi bi-arrow-left gap-2")
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawBiIconClasses")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with a bi- class but no leading bi space" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestView
            def view_template
              i(class: "bi-chevron-right")
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end

    context "with unrelated Bootstrap classes" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestView
            def view_template
              div(class: "btn btn-primary")
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end

    context "when using the Icon() atom" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestView
            def view_template
              Icon(name: "chevron-right")
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end
  end

  context "when file is in app/components/glass_morph (non-atom)" do
    let(:test_file_path) { "app/components/glass_morph/molecules/test_molecule.rb" }

    context "with raw bi bi-* class" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestMolecule
            def view_template
              i(class: "bi bi-x-lg")
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("NoRawBiIconClasses")
        expect(cop_output).to include("1 offense detected")
      end
    end
  end

  context "when file is in app/components/glass_morph/atoms (excluded)" do
    let(:test_file_path) { "app/components/glass_morph/atoms/test_atom.rb" }

    context "with raw bi bi-* class" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestAtom
            def view_template
              i(class: "bi bi-chevron-right")
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end
  end

  context "when file is outside glass_morph (not included)" do
    let(:test_file_path) { "app/components/shared/test_component.rb" }

    context "with raw bi bi-* class" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def view_template
              i(class: "bi bi-chevron-right")
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
