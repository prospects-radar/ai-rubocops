# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Flags a database id rendered into prompt text.
      #
      # A record id tells the model nothing about the company, person or event
      # it belongs to, costs tokens on every run, and invites the model to
      # quote or reason about it. ProspectsRadar's #1646 audit found
      # `"product": {"id": 20}`, `"company": {"id": 314}` and
      # `"prospect_company": {"id": 5157}` in the scoring and DMU payloads
      # (#1659, #1669).
      #
      # Flagged inside a prompt class: an id read (`x[:id]`, `x["id"]`,
      # `x[:company_id]`, `x.id`, `x.company_id`) that is interpolated into a
      # string or is the value of a hash pair (a payload that will be
      # rendered as JSON).
      #
      # When the answer has to be mapped back to a record, give the model a
      # short positional handle (`E1`, `E2`) and keep the id-to-handle map in
      # Ruby. Where an id genuinely must reach the model, disable the cop on
      # that line with the reason.
      #
      # @example
      #   # bad
      #   "Event #{event[:id]}: #{event[:title]}"
      #   { id: company[:id], name: company[:name] }.to_json
      #
      #   # good
      #   "E#{index + 1}: #{event[:title]}"
      #   { name: company[:name] }.to_json
      #
      class PromptNoRecordIds < Base
        MSG = "Prompt text renders the record id `%<source>s`. An id means nothing to the model: " \
              "render a fact, or a positional handle mapped back in Ruby."

        ID_NAME = /\A(id|\w+_id)\z/

        def on_send(node)
          return unless id_read?(node)
          return unless rendered?(node)

          add_offense(node, message: format(MSG, source: node.source))
        end
        alias on_csend on_send

        private

        def id_read?(node)
          if node.method?(:[])
            key = node.first_argument
            node.arguments.one? && key&.type?(:sym, :str) && key.value.to_s.match?(ID_NAME)
          else
            node.receiver && !node.arguments? && node.method_name.to_s.match?(ID_NAME)
          end
        end

        # Interpolated into a string, or the value of a hash pair, possibly
        # through a `.to_s` / `|| fallback` on the way.
        def rendered?(node)
          current = node
          current = current.parent while current.parent&.type?(:send, :csend, :or) && wrapper?(current.parent, current)

          parent = current.parent
          return false unless parent

          (parent.begin_type? && parent.parent&.dstr_type?) ||
            (parent.pair_type? && parent.value.equal?(current))
        end

        def wrapper?(parent, child)
          return true if parent.or_type?

          parent.receiver.equal?(child) && %i[to_s to_i presence].include?(parent.method_name)
        end
      end
    end
  end
end
