# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Ensures Lookbook preview files only use GlassMorph components.
      #
      # The Lookbook component library should exclusively showcase the
      # GlassMorph design system. Preline components must not appear
      # in component previews.
      #
      # @example
      #   # bad - Preline component in preview
      #   class ButtonPreview < Lookbook::Preview
      #     def default
      #       render Components::Preline::Button.new(text: "Click")
      #     end
      #   end
      #
      #   # good - GlassMorph component in preview
      #   class ButtonPreview < Lookbook::Preview
      #     def default
      #       render Components::GlassMorph::Atoms::Button.new(text: "Click")
      #     end
      #   end
      #
      class LookbookOnlyGlassMorph < Base
        MSG = "Lookbook previews must only use GlassMorph components. " \
              "Found non-GlassMorph component reference: %<component>s"

        PRELINE_PATTERN = /Components::Preline/

        def on_const(node)
          return unless in_preview_file?

          const_name = node.source
          return unless const_name.match?(PRELINE_PATTERN)

          add_offense(node, message: format(MSG, component: const_name))
        end

        private

        def in_preview_file?
          processed_source.file_path.include?("spec/components/previews/")
        end
      end
    end
  end
end
