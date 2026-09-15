# frozen_string_literal: true

require_relative "decision_allowance"

module RuboCop
  module Cop
    module SharedWork
      # Refuses a colleague's name on a row of a shared work list.
      #
      # ADR-0063 fixed what a row says about the person holding the work: that it
      # is held, and nothing more. ADR-0087 then took away the role that used to
      # guard the page, which leaves this property as one of the three things
      # keeping the list inside its purpose. `assignment_label` and `creator_label`
      # in `unattended_opportunities/index.rb` are where that goes right today, and
      # they are two method bodies away from going wrong.
      #
      # The cop reads the shape `assigned_to.full_name`: a name-ish method on a
      # colleague-ish receiver. What it cannot see is a name that arrives already
      # rendered — a presenter returning a string, an I18n interpolation fed from
      # somewhere else, a column that happens to hold a person's name. Those stay
      # the reviewer's job, and the checklist in ADR-0087 is where they are listed.
      #
      # @example
      #   # bad — the row names the colleague
      #   task.assigned_to.full_name
      #   stalled.assignee&.email
      #
      #   # good — the row says the work is held
      #   t("unattended_opportunities.row.assigned")
      #
      #   # good — the rule that raised the task, which is not a person
      #   task.action_rule&.name
      class NoPersonNameInWorkList < Base
        include DecisionAllowance

        MSG = "A shared work list says work is held, never by whom (ADR-0063, ADR-0087). `%<receiver>s.%<method>s` " \
              "puts a colleague's name on the row. Name the work instead, or say why this one is different " \
              "with `# shared-work-allowed: ADR-0087`."

        NAME_METHODS = %i[
          name full_name display_name short_name first_name last_name
          initials email email_address username handle
        ].to_set.freeze

        # The receivers that are a colleague. `current_user` is absent on purpose:
        # the reader's own name, in a greeting or a menu, says nothing about anyone
        # else — #1107 hit exactly that and had to narrow its own assertion.
        DEFAULT_PERSON_RECEIVERS = %w[
          assigned_to assignee created_by creator executed_by completed_by
          owner user account_user member colleague
        ].freeze

        def on_send(node)
          return unless NAME_METHODS.include?(node.method_name)

          receiver = person_receiver(node.receiver)
          return unless receiver
          return if allowed_by_decision?(node)

          add_offense(node.loc.selector, message: format(MSG, receiver: receiver, method: node.method_name))
        end
        alias on_csend on_send

        private

        # The name of the receiver when it reads as a colleague: `task.assigned_to`,
        # a bare `assignee`, or `@assigned_to`.
        def person_receiver(node)
          name =
            case node&.type
            when :send, :csend then node.method_name.to_s
            when :lvar, :ivar then node.children.first.to_s.delete_prefix("@")
            end

          name if name && person_receivers.include?(name)
        end

        def person_receivers
          @person_receivers ||= begin
            configured = Array(cop_config["PersonReceivers"]).map(&:to_s)
            configured.empty? ? DEFAULT_PERSON_RECEIVERS : configured
          end
        end
      end
    end
  end
end
