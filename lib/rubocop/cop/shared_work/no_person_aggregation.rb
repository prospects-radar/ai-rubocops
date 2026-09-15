# frozen_string_literal: true

require_relative "decision_allowance"

module RuboCop
  module Cop
    module SharedWork
      # Refuses a grouping, count, or ordering keyed on a colleague, in the files
      # that render a shared work list.
      #
      # ADR-0063 and ADR-0087. A backlog the whole team reads is collaboration; the
      # same backlog aggregated per person is a productivity measurement, and
      # WP249 §6.4 is about what an employer gets shown. One `group_by(&:assigned_to_id)`
      # is the entire distance between the two, and it is a line somebody can add in
      # good faith while building a filter.
      #
      # The `Include` list in `.rubocop.yml` is what says which files are a shared
      # work list. That list is a declaration, not a detection: a new list added
      # somewhere else is outside this cop until somebody adds its path. Say so in
      # the ticket that builds it.
      #
      # @example
      #   # bad — the list, counted per person
      #   tasks.group_by(&:assigned_to_id)
      #   stalled.sort_by { |task| task.assigned_to.name }
      #   Task.open_tasks.order(:assigned_to_id).count
      #
      #   # good — ordered by how late the work is, which is what the list is for
      #   stalled.sort_by(&:stalled_since)
      #   opportunities.group_by(&:prospect_id)
      #
      #   # good — an association load, which aggregates nothing
      #   Task.open_tasks.includes(:assigned_to)
      class NoPersonAggregation < Base
        include DecisionAllowance

        MSG = "`%<method>s` keyed on `%<key>s` turns a shared work list into a measurement per person " \
              "(ADR-0063, ADR-0087). Order and group by the work — how late it is, which prospect it is " \
              "about. If this one is deliberate, say so with `# shared-work-allowed: ADR-0087`."

        # Only the calls that fold many rows into a per-key answer, or put the
        # rows in an order somebody reads down. `pluck` and `includes` are not
        # here: naming a person column is not the same as reporting on it.
        AGGREGATIONS = %i[group group_by order reorder sort sort_by tally count index_by partition].to_set.freeze

        # What a colleague is called in this codebase, on a task and on a row of
        # the list. `stakeholder` is deliberately absent — that is the prospect's
        # own contact, not somebody who works here.
        DEFAULT_PERSON_KEYS = %w[
          assigned_to assigned_to_id assignee assignee_id
          created_by created_by_id creator creator_id
          executed_by executed_by_id completed_by completed_by_id
          owner owner_id user user_id account_user account_user_id
        ].freeze

        def on_send(node)
          return unless AGGREGATIONS.include?(node.method_name)

          key = person_key(node)
          return unless key
          return if allowed_by_decision?(node)

          add_offense(node.loc.selector, message: format(MSG, method: node.method_name, key: key))
        end
        alias on_csend on_send

        private

        # The person key this call is keyed on, or nil. Reads the arguments and,
        # when the call takes a block, the block's body: `group_by(&:assigned_to_id)`
        # and `sort_by { |t| t.assigned_to.name }` are the same mistake written twice.
        def person_key(node)
          haystack = [*node.arguments.map(&:source), block_body_source(node)].compact.join("\n")
          return nil if haystack.empty?

          person_keys.find { |key| haystack.match?(/(?<![a-z_])#{Regexp.escape(key)}(?![a-z_])/) }
        end

        def block_body_source(node)
          parent = node.parent
          return nil unless parent&.type?(:block, :numblock) && parent.send_node == node

          parent.body&.source
        end

        def person_keys
          @person_keys ||= begin
            configured = Array(cop_config["PersonKeys"]).map(&:to_s)
            configured.empty? ? DEFAULT_PERSON_KEYS : configured
          end
        end
      end
    end
  end
end
