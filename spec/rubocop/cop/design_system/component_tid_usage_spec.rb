# frozen_string_literal: true

require "open3"
require "spec_helper"

RSpec.describe "RuboCop::Cop::DesignSystem::ComponentTidUsage" do
  subject(:cop_output) do
    # Avoid RUBYOPT space-path issue (Ruby 4.0 splits RUBYOPT on whitespace):
    # use RbConfig.ruby + Gem.bin_path instead of `bundle exec rubocop`
    rubocop = Gem.bin_path("rubocop", "rubocop")
    cmd = [ RbConfig.ruby, rubocop, test_file_path,
           "--only", "DesignSystem/ComponentTidUsage", "--format", "simple" ]
    out, = Open3.capture2e({ "RUBYOPT" => nil }, *cmd)
    out
  end

  let(:test_file_path) { "tmp/test_component.rb" }

  before do
    File.write(test_file_path, test_content)
  end

  after do
    File.delete(test_file_path) if File.exist?(test_file_path)
  end

  context "when file is in app/components" do
    let(:test_file_path) { "app/components/test_component.rb" }

    context "with data: { testid: ... }" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              div(data: { testid: "submit-button" })
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with data: { test_id: ... }" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              div(data: { test_id: "submit-button" })
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with data_testid: ..." do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              button(data_testid: "cancel-btn")
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with :'data-testid' => ..." do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              button(:"data-testid" => "cancel-btn")
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with 'data-testid' => ..." do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              button("data-testid" => "cancel-btn")
            end
          end
        RUBY
      end

      it "registers an offense" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with root_attributes(test_id: ...)" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              div(**root_attributes(base_class: "my-class", test_id: "my-element"))
            end
          end
        RUBY
      end

      it "registers an offense with specific message" do
        expect(cop_output).to include("Remove test_id from root_attributes")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with nested data hash in form_with" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              form_with(
                model: @product,
                html: {
                  data: {
                    testid: "test-form"
                  }
                }
              )
            end
          end
        RUBY
      end

      it "registers an offense for nested hash" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "when already using tid helper" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              div(**tid("submit-button"))
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end

    context "when using tid with other attributes" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              button(**tid("cancel-btn"), class: "btn btn-secondary")
            end
          end
        RUBY
      end

      it "does not register an offense" do
        expect(cop_output).to include("no offenses detected")
      end
    end

    context "when data hash has other keys" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              div(data: { testid: "my-div", controller: "expand" })
            end
          end
        RUBY
      end

      it "registers an offense but preserves other keys on autocorrect" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end

    context "with GlassMorph component method calls" do
      let(:test_content) do
        <<~RUBY
          # frozen_string_literal: true

          class TestComponent
            def render
              Button(text: "Submit", data: { testid: "submit-btn" })
            end
          end
        RUBY
      end

      it "registers an offense for capitalized component methods" do
        expect(cop_output).to include("Use tid helper for test IDs")
        expect(cop_output).to include("1 offense detected")
      end
    end
  end

  context "when file is in app/views" do
    let(:test_file_path) { "app/views/test_view.rb" }

    let(:test_content) do
      <<~RUBY
        # frozen_string_literal: true

        class TestView
          def render
            div(data: { testid: "view-element" })
          end
        end
      RUBY
    end

    it "registers an offense for view files" do
      expect(cop_output).to include("Use tid helper for test IDs")
      expect(cop_output).to include("1 offense detected")
    end
  end

  context "when not in a component or view file" do
    let(:test_file_path) { "app/models/example.rb" }

    let(:test_content) do
      <<~RUBY
        # frozen_string_literal: true

        class Example
          def test_method
            div(data: { testid: "submit-button" })
          end
        end
      RUBY
    end

    it "does not register an offense" do
      expect(cop_output).to include("no offenses detected")
    end
  end
end
