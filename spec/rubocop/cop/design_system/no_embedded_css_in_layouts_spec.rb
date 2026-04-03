# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::NoEmbeddedCssInLayouts, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/layouts/glass_morph/**/*.rb"
      ]
    }
  end

  let(:source_file_path) { "app/layouts/glass_morph/test_layout.rb" }

  it "registers an offense for embedded CSS inside a style block" do
    expect_offense(<<~RUBY, source_file_path)
      class TestLayout
        def render_head
          style do
          ^^^^^ Do not embed CSS in GlassMorph layouts. Move stable rules into the GlassMorph stylesheet tree.
            raw ".auth-page { min-height: 100vh; }"
          end
        end
      end
    RUBY
  end

  it "allows stylesheet links" do
    expect_no_offenses(<<~RUBY, source_file_path)
      class TestLayout
        def render_head
          stylesheet_link_tag "glass_morph/styles"
        end
      end
    RUBY
  end

  it "allows variable bootstrapping via File.read" do
    expect_no_offenses(<<~RUBY, source_file_path)
      class TestLayout
        def render_head
          style { raw File.read(variables_path).html_safe }
        end
      end
    RUBY
  end
end
