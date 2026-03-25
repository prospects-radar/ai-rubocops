# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces consistent modal usage in GlassMorph components and views.
      #
      # All modals in GlassMorph code must use the design system modal components
      # (Modal, TurboModal, ConfirmationModal, DangerModal) instead of raw
      # Bootstrap modal HTML or custom modal implementations.
      #
      # Files that ARE modal body implementations (onboarding step components,
      # turbo confirm dialog, etc.) are excluded — they intentionally render
      # modal-content/modal-dialog structure as part of their definition.
      #
      # @example
      #   # bad - raw Bootstrap modal in GlassMorph view
      #   div(class: "modal fade", id: "myModal")
      #   div(class: "modal-dialog")
      #   div(class: "modal-content")
      #
      #   # good - use design system modal component
      #   Modal(id: "myModal", title: "Title")
      #   TurboModal.new(title: "Title", close_path: path)
      #   ConfirmationModal(title: "Confirm", message: "Are you sure?")
      #
      #   # ignored - these files implement modal body structure, not consume it
      #   # app/components/glass_morph/organisms/onboarding/*.rb
      #   # app/components/glass_morph/organisms/simple_onboarding/*.rb
      #   # app/components/glass_morph/organisms/turbo_confirm_dialog.rb
      #
      class ModalUsage < Base
        MSG = "Use design system modal components (Modal, TurboModal, ConfirmationModal, DangerModal) " \
              "instead of raw modal HTML. See app/components/glass_morph/organisms/ for available modals."

        RAW_MODAL_CLASSES = /\b(modal\s+fade|modal-dialog|modal-content)\b/

        # Paths that ARE modal body implementations — they intentionally contain
        # modal-content/modal-dialog class strings as part of their own structure.
        MODAL_BODY_PATHS = [
          "organisms/onboarding/",
          "organisms/simple_onboarding/",
          "organisms/turbo_confirm_dialog.rb",
          # Wizard step views render modal-content/modal-footer as their top-level structure
          "_wizard/",
          # Non-wizard views that implement inline modal bodies
          "action_rules/show",
          "action_instances/new",
          "admin/archived_tasks/",
          "prospect_timeline_events/show"
        ].freeze

        # Match class: "modal fade" or class: "modal-dialog" etc.
        def_node_matcher :class_with_modal?, <<~PATTERN
          (pair (sym {:class}) (str $_))
        PATTERN

        def on_pair(node)
          return unless in_glass_morph_file?
          return if modal_body_component?

          class_with_modal?(node) do |class_value|
            add_offense(node) if class_value.match?(RAW_MODAL_CLASSES)
          end
        end

        private

        def in_glass_morph_file?
          path = processed_source.file_path
          path.include?("app/components/glass_morph/") ||
            path.include?("app/views/glass_morph/")
        end

        def modal_body_component?
          path = processed_source.file_path
          MODAL_BODY_PATHS.any? { |pattern| path.include?(pattern) }
        end
      end
    end
  end
end
