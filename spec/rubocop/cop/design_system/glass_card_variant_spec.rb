# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::GlassCardVariant, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) do
    {
      "Include" => [
        "app/components/glass_morph/**/*.rb",
        "app/views/glass_morph/**/*.rb",
        "spec/components/glass_morph/**/*.rb"
      ]
    }
  end

  let(:source_file_path) { "app/views/glass_morph/test_view.rb" }

  it "registers an offense for legacy default variant" do
    expect_offense(<<~RUBY, source_file_path)
      class TestView
        def view_template
          GlassCard(variant: :default)
                    ^^^^^^^^^^^^^^^^^ Use a supported GlassCard variant: :glass, :solid, :section, or :elevated.
        end
      end
    RUBY
  end

  it "registers an offense for unsupported minimal variant" do
    expect_offense(<<~RUBY, source_file_path)
      class TestView
        def view_template
          GlassCard(variant: :minimal)
                    ^^^^^^^^^^^^^^^^^ Use a supported GlassCard variant: :glass, :solid, :section, or :elevated.
        end
      end
    RUBY
  end

  it "allows supported variants" do
    expect_no_offenses(<<~RUBY, source_file_path)
      class TestView
        def view_template
          GlassCard(variant: :glass)
          GlassCard(variant: :solid)
          GlassCard(variant: :section)
          GlassCard(variant: :elevated)
        end
      end
    RUBY
  end

  it "ignores dynamic variants" do
    expect_no_offenses(<<~RUBY, source_file_path)
      class TestView
        def view_template
          GlassCard(variant: current_variant)
        end
      end
    RUBY
  end
end
