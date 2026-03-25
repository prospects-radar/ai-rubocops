# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects Phlex DSL elements whose class string contains "score-badge"
      # that should use the ScoreBadge atom instead.
      #
      # This is analogous to UseRealBadgeComponent but for score-specific badges.
      # The ScoreBadge atom provides automatic colour coding based on the score
      # value and a consistent pill style.
      #
      # No auto-correct is provided because the score value must be passed as a
      # parameter (score:) and extracting it from an arbitrary dynamic class
      # expression is not reliably possible statically.
      #
      # @example Bad — raw element with score-badge class
      #   span(class: "inline-flex rounded small fw-semibold score-badge #{score_class}") do
      #     score.to_s
      #   end
      #
      #   div(class: "score-badge score-badge-sm", **tid("score")) { value }
      #
      # @example Good — use the ScoreBadge atom
      #   ScoreBadge(score: score)
      #   ScoreBadge(score: score, format: :percentage, size: :sm)
      #   render Components::GlassMorph::Atoms::ScoreBadge.new(score: score, size: :xs)
      #
      class UseRealScoreBadgeComponent < Base
        SCORE_BADGE_PATTERN = /\bscore-badge\b/.freeze

        CHECKED_ELEMENTS = %i[span div Span Box].freeze

        MSG = "Use ScoreBadge(score: ...) instead of %<method>s() with a " \
              "\"score-badge\" class. ScoreBadge provides automatic colour " \
              "coding (green/amber/red) and consistent pill styling via " \
              "size: (:xs, :sm, :md, :lg) and format: (:numeric, :percentage). " \
              "Example: ScoreBadge(score: score) or " \
              "ScoreBadge(score: score, format: :percentage, size: :sm)."

        def on_send(node)
          return if node.receiver
          return unless CHECKED_ELEMENTS.include?(node.method_name)

          classes = class_value(node)
          return unless classes&.match?(SCORE_BADGE_PATTERN)

          add_offense(
            node,
            message: format(MSG, method: node.method_name)
          )
        end

        private

        def class_value(node)
          hash_arg = node.arguments.find(&:hash_type?)
          return nil unless hash_arg

          class_pair = hash_arg.pairs.find { |p| p.key.sym_type? && p.key.value == :class }
          return nil unless class_pair

          value = class_pair.value
          if value.str_type?
            value.value
          elsif value.dstr_type?
            value.children.select(&:str_type?).map(&:value).join
          end
        end
      end
    end
  end
end
