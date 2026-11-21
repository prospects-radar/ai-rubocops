# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Flags an invented value used as a fallback in a prompt class.
      #
      # `company[:domain] || "unknown.com"` and `company[:industry] || "General"`
      # turn a missing fact into a plausible one. The model cannot tell the
      # placeholder from data, so it searches for `site:unknown.com` or reasons
      # about a "General" industry (#1679). Leave the field out when it is
      # missing, or say in a sentence that it is not known.
      #
      # Flagged: `x || "literal"` (including `x.presence || "literal"`) where the
      # literal is a non-empty string that is not a sentence. A sentence has a
      # space and ends in `.`, `!`, `?` or `:` ("No website is known."), and
      # tells the model the fact is absent instead of inventing it. An empty
      # string renders nothing and is not flagged; neither are numbers and
      # symbols.
      #
      # @example
      #   # bad
      #   company[:industry] || "General"
      #   company[:domain].presence || "unknown.com"
      #   name || "Unknown Company"
      #
      #   # good
      #   { name: company[:name], industry: company[:industry] }.compact
      #   company[:domain] || "No website is known."
      #
      class PromptNoPlaceholderFallback < Base
        MSG = "`|| %<literal>s` invents a value the model cannot tell from data. " \
              "Leave the field out, or say in a sentence that it is not known."

        SENTENCE = /\s.*[.!?:]\z/m

        def on_or(node)
          fallback = node.rhs
          return unless fallback.str_type?

          value = fallback.value.to_s
          return if value.strip.empty? || value.match?(SENTENCE)

          add_offense(fallback, message: format(MSG, literal: fallback.source))
        end
      end
    end
  end
end
