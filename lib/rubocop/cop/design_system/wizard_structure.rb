# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces consistent wizard structure in GlassMorph views.
      #
      # Wizard views must use the design system wizard components
      # (WizardModal, ModalWizard, WizardNavigation, ModalStep, ModalStepIndicator)
      # and follow the standard wizard patterns.
      #
      # Rules enforced:
      # 1. Wizard views must include WizardDataPreservation concern
      # 2. Wizard views must use WizardNavigation for footer buttons
      # 3. Wizard views must NOT contain raw step counting or progress logic
      #
      # @example
      #   # bad - custom wizard navigation
      #   div(class: "wizard-footer") do
      #     a(href: previous_path) { "Back" }
      #     button(type: :submit) { "Next" }
      #   end
      #
      #   # good - use WizardNavigation component
      #   WizardNavigation(
      #     cancel_path: cancel_path,
      #     back_path: previous_step_path,
      #     next_label: t("wizard.next"),
      #     submit: last_step?
      #   )
      #
      class WizardStructure < Base
        MSG_MISSING_CONCERN = "Wizard views should include WizardDataPreservation concern " \
                              "for consistent data preservation between steps."

        WIZARD_PATH_PATTERN = /wizard/i

        def on_class(node)
          return unless wizard_file?
          return unless in_glass_morph_file?

          # Check if WizardDataPreservation is included
          includes_concern = false
          node.each_descendant(:send) do |send_node|
            if send_node.method_name == :include
              send_node.arguments.each do |arg|
                if arg.source.include?("WizardDataPreservation")
                  includes_concern = true
                  break
                end
              end
            end
          end

          add_offense(node, message: MSG_MISSING_CONCERN) unless includes_concern
        end

        private

        def wizard_file?
          processed_source.file_path.match?(WIZARD_PATH_PATTERN)
        end

        def in_glass_morph_file?
          path = processed_source.file_path
          path.include?("app/views/glass_morph/") ||
            path.include?("app/components/glass_morph/")
        end
      end
    end
  end
end
