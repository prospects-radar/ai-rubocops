# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::ComponentTidUsage, :config do
  subject(:cop) { described_class.new(config) }

  context "when file is in app/components" do
    let(:source_file_path) { "app/components/test_component.rb" }

    it "registers offense for data: { testid: ... }" do
      expect_offense(<<~RUBY, source_file_path)
        class TestComponent
          def render
            div(data: { testid: "submit-button" })
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tid` helper for test IDs[...]
          end
        end
      RUBY
    end

    it "registers offense for data: { test_id: ... }" do
      expect_offense(<<~RUBY, source_file_path)
        class TestComponent
          def render
            div(data: { test_id: "submit-button" })
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tid` helper for test IDs[...]
          end
        end
      RUBY
    end

    it "registers offense for data_testid: ..." do
      expect_offense(<<~RUBY, source_file_path)
        class TestComponent
          def render
            button(data_testid: "cancel-btn")
                   ^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tid` helper for test IDs[...]
          end
        end
      RUBY
    end

    it "registers offense for root_attributes(test_id: ...)" do
      expect_offense(<<~RUBY, source_file_path)
        class TestComponent
          def render
            div(**root_attributes(base_class: "my-class", test_id: "my-element"))
                                                          ^^^^^^^^^^^^^^^^^^^^^ Remove test_id from root_attributes[...]
          end
        end
      RUBY
    end

    it "does not register offense when using tid helper" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestComponent
          def render
            div(**tid("submit-button"))
          end
        end
      RUBY
    end

    it "does not register offense when using tid with other attributes" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class TestComponent
          def render
            button(**tid("cancel-btn"), class: "btn btn-secondary")
          end
        end
      RUBY
    end
  end

  context "when file is in app/views" do
    let(:source_file_path) { "app/views/test_view.rb" }

    it "registers offense for view files" do
      expect_offense(<<~RUBY, source_file_path)
        class TestView
          def render
            div(data: { testid: "view-element" })
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `tid` helper for test IDs[...]
          end
        end
      RUBY
    end
  end

  context "when not in a component or view file" do
    let(:source_file_path) { "app/models/example.rb" }

    it "does not register an offense" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Example
          def test_method
            div(data: { testid: "submit-button" })
          end
        end
      RUBY
    end
  end
end
