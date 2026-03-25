# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Prevents the use of Preline components in NewUI components.
      #
      # NewUI is the official design system using Bootstrap 5 with glassmorphism.
      # Preline is legacy and should not be mixed with NewUI components.
      #
      # @example
      #   # bad - in app/components/glass_morph/**/*.rb
      #   render Components::Preline::Card.new
      #
      #   # good - in app/components/glass_morph/**/*.rb
      #   render Components::GlassMorph::Molecules::Card.new
      #
      class NoPrelineInGlassMorph < Base
        extend AutoCorrector

        MSG = "Do not use Preline components in NewUI. " \
              "Use NewUI components (Atoms/Molecules/Organisms) instead."

        PRELINE_PATTERN = /Components::Preline/

        COMPONENT_MAPPINGS = {
          "Components::Preline::Button" => "Components::GlassMorph::Atoms::Button",
          "Components::Preline::Icon" => "Components::GlassMorph::Atoms::Icon",
          "Components::Preline::Badge" => "Components::GlassMorph::Atoms::Badge",
          "Components::Preline::Card" => "Components::GlassMorph::Molecules::Card",
          "Components::Preline::Modal" => "Components::GlassMorph::Organisms::Modal",
          "Components::Preline::Input" => "Components::GlassMorph::Atoms::Input",
          "Components::Preline::Select" => "Components::GlassMorph::Atoms::Select",
          "Components::Preline::Checkbox" => "Components::GlassMorph::Atoms::Checkbox"
        }.freeze

        def on_const(node)
          return unless in_glass_morph_file?

          const_name = node.source

          return unless const_name.match?(PRELINE_PATTERN)

          add_offense(node, message: MSG) do |corrector|
            replacement = suggest_replacement(const_name)
            corrector.replace(node, replacement) if replacement
          end
        end

        private

        def in_glass_morph_file?
          processed_source.file_path.include?("app/components/glass_morph/")
        end

        def suggest_replacement(const_name)
          return COMPONENT_MAPPINGS[const_name] if COMPONENT_MAPPINGS.key?(const_name)

          if const_name.start_with?("Components::Preline::")
            component_name = const_name.sub("Components::Preline::", "")
            return "Components::GlassMorph::Atoms::#{component_name}"
          end

          nil
        end
      end
    end
  end
end
