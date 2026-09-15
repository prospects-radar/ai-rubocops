# frozen_string_literal: true

module RuboCop
  module Cop
    module SharedWork
      # The escape hatch the SharedWork cops share.
      #
      # A shared work list may legitimately need one of the shapes these cops
      # refuse — a report the works council itself asked for, a screen that
      # assigns work and therefore has to name the person it assigns it to. What
      # it may not do is acquire that shape because nobody noticed. So the hatch
      # is open, and it costs one line: a comment naming the decision that allows
      # it, on the offending line or the line directly above it.
      #
      #   # shared-work-allowed: ADR-0087 — the assignment control names the
      #   # person it assigns the task to
      #   assigned_to.full_name
      #
      # `ADR-0087` or `#1101` both count: an ADR when the reasoning is written
      # down as a decision, a ticket number when it is written down as a change.
      # A bare `rubocop:disable` also silences these cops, as it silences every
      # cop — it just leaves no trace of who decided what, which is the whole
      # thing this boundary exists to keep.
      module DecisionAllowance
        ALLOWANCE = /shared-work-allowed:\s*(?:ADR-\d{4}|#\d+)/i

        # The offending line and the one above it, and no further. A reason that
        # has drifted three lines from the code it excuses is a reason nobody
        # will move when the code moves.
        def allowed_by_decision?(node)
          line = node.loc.line

          [line, line - 1].any? { |number| comment_text(number)&.match?(ALLOWANCE) }
        end

        private

        def comment_text(line)
          processed_source.comments.find { |comment| comment.loc.line == line }&.text
        end
      end
    end
  end
end
