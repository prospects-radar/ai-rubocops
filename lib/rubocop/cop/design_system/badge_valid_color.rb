# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Ensures Badge components use valid design system color values.
      #
      # The Badge atom accepts `color:` (preferred) or `variant:` (legacy alias).
      # Only the following values are valid:
      #   :slate, :teal, :green, :amber, :red, :blue
      #
      # Bootstrap variant names (:primary, :secondary, :success, :danger, :info, :warning)
      # produce non-existent CSS classes like `gm-badge-primary` and must not be used.
      #
      # @example Bad
      #   Badge(text: "Active", color: :success)
      #   Badge(text: "New", variant: :primary)
      #   Badge(text: "Error", color: :danger)
      #
      # @example Good
      #   Badge(text: "Active", color: :green)
      #   Badge(text: "New", color: :blue)
      #   Badge(text: "Error", color: :red)
      #
      class BadgeValidColor < Base
        extend AutoCorrector

        DEFAULT_VALID_COLORS = %i[slate teal green amber red blue].freeze

        BOOTSTRAP_TO_DESIGN_SYSTEM = {
          primary: :blue,
          secondary: :slate,
          success: :green,
          danger: :red,
          warning: :amber,
          info: :teal,
          light: :slate,
          dark: :slate,
          default: :slate
        }.freeze

        MSG = "Badge `%<param>s: :%<value>s` is not a valid design system color. " \
              "Use `color: :%<replacement>s` instead. Valid colors: %<valid_colors>s."

        MSG_UNKNOWN = "Badge `%<param>s: :%<value>s` is not a valid design system color. " \
                      "Valid colors: %<valid_colors>s."

        RESTRICT_ON_SEND = %i[Badge].freeze

        def on_send(node)
          return if node.receiver

          check_color_param(node, :color)
          check_color_param(node, :variant)
        end

        private

        def valid_colors
          cop_config.fetch("ValidColors", DEFAULT_VALID_COLORS.map(&:to_s)).map(&:to_sym)
        end

        def check_color_param(node, param_name)
          hash_arg = node.arguments.find(&:hash_type?)
          return unless hash_arg

          pair = hash_arg.pairs.find { |p| p.key.value == param_name }
          return unless pair
          return unless pair.value.sym_type?

          color_value = pair.value.value
          return if valid_colors.include?(color_value)

          replacement = BOOTSTRAP_TO_DESIGN_SYSTEM[color_value]

          if replacement
            add_offense(pair, message: format(MSG, param: param_name, value: color_value, replacement: replacement, valid_colors: valid_colors.join(", "))) do |corrector|
              corrector.replace(pair, "color: :#{replacement}")
            end
          else
            add_offense(pair, message: format(MSG_UNKNOWN, param: param_name, value: color_value, valid_colors: valid_colors.join(", ")))
          end
        end
      end
    end
  end
end
