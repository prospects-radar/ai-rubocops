# frozen_string_literal: true

require_relative "decision_allowance"

module RuboCop
  module Cop
    module SharedWork
      # Refuses `ProspectView` in the path of a shared work list.
      #
      # ADR-0082 and ADR-0063: looking is not attention. A `ProspectView` records
      # that somebody opened a page — usage behaviour, and the one input that would
      # turn this list from "what is late" into "who has been busy". It also used to
      # make the list wrong in its own terms: a glance never expired, so one click
      # retired a prospect from the list for the rest of its life.
      #
      # Any mention of the constant in a file in scope is flagged. That is blunt on
      # purpose — there is no reading of a view record that this list needs, so
      # there is no shape worth distinguishing. What the cop does not see is the
      # same data arriving under another name: a `last_seen_at` column, a view count
      # denormalised onto the prospect, an analytics table with a different class.
      #
      # @example
      #   # bad — usage behaviour deciding what is on the list
      #   ProspectView.where(prospect_id: ids).exists?
      #
      #   # good — a task made or finished is what counts as attention
      #   Task.open_tasks.where.not(prospect_id: nil).distinct.pluck(:prospect_id)
      class NoProspectViewRead < Base
        include DecisionAllowance

        MSG = "Looking is not attention (ADR-0082, ADR-0087). `%<constant>s` is usage behaviour, and a shared " \
              "work list decides on work: a task made, finished, or snoozed. If this one is deliberate, " \
              "say so with `# shared-work-allowed: ADR-0082`."

        DEFAULT_BEHAVIOUR_CONSTANTS = %w[ProspectView].freeze

        def on_const(node)
          name = node.const_name
          return unless behaviour_constants.include?(name)
          return if allowed_by_decision?(node)

          add_offense(node, message: format(MSG, constant: name))
        end

        private

        def behaviour_constants
          @behaviour_constants ||= begin
            configured = Array(cop_config["BehaviourConstants"]).map(&:to_s)
            configured.empty? ? DEFAULT_BEHAVIOUR_CONSTANTS : configured
          end
        end
      end
    end
  end
end
