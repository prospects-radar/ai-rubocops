# frozen_string_literal: true

module RuboCop
  module Cop
    module Convention
      # Flags raw `record.id` where an *encoded* id (`record.to_param`) belongs:
      # values under URL/param/dom-id keys in views, presenters and serializers.
      #
      # ProspectsRadar exposes primary keys as per-model Sqids-encoded strings
      # everywhere externally visible (URLs, dom ids, API/automation payloads).
      # The `DecodesHashedIds` controller concern decodes them back at the
      # boundary. A raw `.id` emitted into a rendered hash / dom id / path-helper
      # arg therefore leaks the integer PK AND (once the boundary decodes the
      # param) 404s, because a bare integer is not a valid encoded token.
      #
      # The cop is deliberately narrow: it fires only when the *key* names a
      # URL/dom id and the surrounding call is NOT an ActiveRecord query or an
      # i18n interpolation (where a raw id is correct). Scope it further via
      # `Include`/`Exclude` in .rubocop.yml (views + presenters + serializers).
      #
      # @example
      #   # bad — leaks raw PK, boundary later 404s
      #   new_task_path(prospect_id: @prospect.id)
      #   FlexRow(id: "prospect-#{prospect.id}")
      #   { id: prospect.id, name: prospect.name }
      #
      #   # good
      #   new_task_path(prospect_id: @prospect.to_param)
      #   FlexRow(id: "prospect-#{prospect.to_param}")
      #   { id: prospect.to_param, name: prospect.name }
      #
      #   # good — raw id is correct here (not flagged)
      #   Prospect.find_by(prospect_company_id: company.id) # AR query condition
      #   t("gdpr.requests.show.request_id", id: @request.id) # i18n text
      class EncodeRecordIdsInViews < Base
        extend AutoCorrector

        MSG = "Emit `to_param` (encoded id), not raw `.id`, under `%<key>s:` — " \
              "raw primary keys leak past the encoded-id boundary and 404 on decode. See HashedId."

        # Fixed keys that always name a URL param / dom id / test id.
        DOM_ID_KEYS = %i[id dom_id testid test_id target for].freeze

        # `*_id` keys that stay raw integers (never encoded — see
        # DecodesHashedIds::REGISTRY excludes) or are internal AR foreign keys.
        EXCLUDED_ID_KEYS = %i[
          user_id assigned_to_id assigned_by_id created_by_id updated_by_id
          owner_id member_id sender_id recipient_id prospect_company_id
        ].freeze

        # Calls whose hash argument is DB/query data or display text, where a
        # raw id is correct and must NOT be rewritten to `to_param`.
        SKIP_ENCLOSING_METHODS = %i[
          find find_by find_by! where find_or_create_by find_or_initialize_by
          create create! new build update update! update_all update_columns
          assign_attributes exists? t translate
        ].freeze

        def on_pair(node)
          key = node.key
          return unless key.sym_type?
          return unless monitored_key?(key.value)
          return if skipped_context?(node)

          each_raw_id_send(node.value) do |send_node|
            add_offense(send_node.loc.selector, message: format(MSG, key: key.value)) do |corrector|
              corrector.replace(send_node.loc.selector, "to_param")
            end
          end
        end

        private

        def monitored_key?(key)
          return true if DOM_ID_KEYS.include?(key)

          key.to_s.end_with?("_id") && !EXCLUDED_ID_KEYS.include?(key)
        end

        # A raw record id read: `receiver.id` with a real receiver (not a bare
        # local `id`, not `Model.id`). Matches direct values and interpolations.
        def each_raw_id_send(value_node)
          value_node.each_node(:send, :csend) do |send_node|
            next unless send_node.method_name == :id
            next if send_node.arguments.any?

            receiver = send_node.receiver
            next if receiver.nil? || receiver.const_type?

            yield send_node
          end
        end

        # Skip when the hash is an ActiveRecord query condition or i18n
        # interpolation — walk up pair -> hash -> enclosing send.
        def skipped_context?(pair_node)
          hash = pair_node.parent
          return false unless hash&.hash_type?

          enclosing = hash.parent
          return false unless enclosing&.send_type?

          SKIP_ENCLOSING_METHODS.include?(enclosing.method_name)
        end
      end
    end
  end
end
