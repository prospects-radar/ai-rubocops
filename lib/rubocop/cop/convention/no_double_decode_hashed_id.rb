# frozen_string_literal: true

module RuboCop
  module Cop
    module Convention
      # Flags decoding a top-level request param that the `DecodesHashedIds`
      # controller concern has ALREADY decoded at the boundary.
      #
      # The concern rewrites `params[:prospect_id]` (and every other registry
      # param) to its raw integer PK before the action runs. Decoding it a second
      # time — `Prospect.decode_param(params[:prospect_id])`,
      # `resolve_param_to_id(params[:company_id])`, `Task.from_param(params[:task_id])`
      # — feeds a bare integer to Sqids, which fails the canonical round-trip guard
      # and returns nil. That produced the "empty svg / 404 / nil lookup" class of
      # bugs repeatedly during the encoded-id rollout.
      #
      # Fires ONLY when all three hold, to stay false-positive free:
      #   * the key is a registry param (config `RegistryKeys`, mirrors
      #     HashedIds::REGISTRY) — non-registry params (scroll_to_event_id, email
      #     link tokens) are NOT decoded by the concern, so decoding is correct;
      #   * the read is TOP-LEVEL `params[:key]` / `params.fetch(:key)` — nested
      #     `params.dig(:wizard_data, :product_id)` is not decoded by the concern;
      #   * the file is a controller (config `Include`) — services and channels
      #     receive raw params and legitimately decode them.
      #
      # @example
      #   # bad — params[:prospect_id] is already the raw PK
      #   Prospect.decode_param(params[:prospect_id])
      #   Company.resolve_param_to_id(params[:company_id])
      #   Task.from_param(params[:task_id])
      #
      #   # good — use the decoded value directly
      #   Prospect.find(params[:prospect_id])
      #   params[:prospect_id]
      #
      #   # good — nested params are NOT decoded by the concern, decode them here
      #   Product.decode_param(params.dig(:wizard_data, :product_id))
      class NoDoubleDecodeHashedId < Base
        MSG = "`params[%<key>s]` is already decoded by DecodesHashedIds — don't `%<method>s` it again " \
              "(re-decoding a raw PK returns nil). Use the value directly or `Model.find(params[%<key>s])`."

        # Mirrors HashedIds::REGISTRY keys. Overridable via cop config so the app
        # registry stays the single runtime source and this list tracks it.
        DEFAULT_REGISTRY_KEYS = %w[
          account_id assistant_id company_id company_timeline_event_id
          customer_company_id product_id prospect_id stakeholder_id task_id
          follow_up_from_id action_rule_id criterion_id api_key_id
        ].freeze

        # (send RECEIVER :decode_param  (send (send nil :params) :[]    (sym $_)))
        # (send RECEIVER :decode_param  (send (send nil :params) :fetch (sym $_) ...))
        def_node_matcher :decode_of_top_level_param, <<~PATTERN
          (send _ ${:decode_param :resolve_param_to_id :from_param}
            (send (send nil? :params) {:[] :fetch} (sym $_) ...))
        PATTERN

        def on_send(node)
          decode_of_top_level_param(node) do |method, key|
            next unless registry_keys.include?(key.to_s)

            add_offense(node.loc.selector, message: format(MSG, key: key.inspect, method: method))
          end
        end

        private

        def registry_keys
          @registry_keys ||= begin
            configured = Array(cop_config["RegistryKeys"]).map(&:to_s)
            configured.empty? ? DEFAULT_REGISTRY_KEYS : configured
          end
        end
      end
    end
  end
end
