# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::NoRawBiIconClasses, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/views/glass_morph/**/*.rb",
        "app/components/glass_morph/**/*.rb"
      ],
      "Exclude" => [
        "app/components/glass_morph/atoms/**/*.rb"
      ]
    }
  end

  context "when file is in app/views/glass_morph" do
    let(:source_file_path) { "app/views/glass_morph/test_view.rb" }

    it "registers offense for plain bi bi-* class" do
      expect_offense(<<~RUBY, source_file_path)
        class TestView
          def view_template
            i(class: "bi bi-chevron-right")
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "icon-name")[...]
          end
        end
      RUBY
    end

    it "registers offense for bi bi-* mixed into other classes" do
      expect_offense(<<~RUBY, source_file_path)
        class TestView
          def view_template
            div(class: "d-flex bi bi-arrow-left gap-2")
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "icon-name")[...]
          end
        end
      RUBY
    end

    it "does not register offense for bi- class without leading bi space" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestView
          def view_template
            i(class: "bi-chevron-right")
          end
        end
      RUBY
    end

    it "does not register offense for unrelated Bootstrap classes" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestView
          def view_template
            div(class: "btn btn-primary")
          end
        end
      RUBY
    end

    it "does not register offense when using Icon() atom" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestView
          def view_template
            Icon(name: "chevron-right")
          end
        end
      RUBY
    end
  end

  context "when file is in app/components/glass_morph (non-atom)" do
    let(:source_file_path) { "app/components/glass_morph/molecules/test_molecule.rb" }

    it "registers offense for raw bi bi-* class" do
      expect_offense(<<~RUBY, source_file_path)
        class TestMolecule
          def view_template
            i(class: "bi bi-x-lg")
              ^^^^^^^^^^^^^^^^^^^ Use `Icon(name: "icon-name")[...]
          end
        end
      RUBY
    end
  end

  context "when file is in app/components/glass_morph/atoms (excluded)" do
    let(:source_file_path) { "app/components/glass_morph/atoms/test_atom.rb" }

    it "does not register offense" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestAtom
          def view_template
            i(class: "bi bi-chevron-right")
          end
        end
      RUBY
    end
  end

  context "when file is outside glass_morph" do
    let(:source_file_path) { "app/components/shared/test_component.rb" }

    it "does not register offense" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestComponent
          def view_template
            i(class: "bi bi-chevron-right")
          end
        end
      RUBY
    end
  end
end
