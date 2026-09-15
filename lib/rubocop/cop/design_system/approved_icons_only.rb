# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Holds every `Icon` written with a literal name against the approved icon
      # set, so the set is enforced rather than merely written down.
      #
      # The names come from `ApprovedIcons` when the consuming project lists them
      # in its config, or from `ApprovedIconsFile` + `ApprovedIconsConstant`, which
      # reads a `%w[…]` constant straight out of the project so the constant stays
      # the one place the set is written. With neither configured the cop is silent:
      # an unconfigurable cop that flags every icon would be worse than no cop.
      #
      # A name the cop cannot read — a method call, a hash lookup, a variable — is
      # left alone. `icon_map.css` is the backstop there: a name with no rule in it
      # renders no glyph.
      #
      # @example Bad
      #   Icon(name: "sparkles")
      #   render Components::GlassMorph::Atoms::Icon.new(name: "building-office")
      #
      # @example Good
      #   Icon(name: "buildings")
      #   Icon(name: icon_for(@status))
      #
      class ApprovedIconsOnly < Base
        MSG = "`%<name>s` is not in the approved icon set. Pick an approved name, or add it to " \
              "APPROVED_ICONS, the design-system skill and icon_map.css together."

        # `Icon(name: "x")` — the Phlex::Kit short form.
        def_node_matcher :short_form_icon, <<~PATTERN
          (send nil? :Icon (hash <$(pair (sym :name) $(str _)) ...>))
        PATTERN

        # `Components::GlassMorph::Atoms::Icon.new(name: "x")`, rendered or not.
        def_node_matcher :long_form_icon, <<~PATTERN
          (send (const _ :Icon) :new (hash <$(pair (sym :name) $(str _)) ...>))
        PATTERN

        def on_send(node)
          pair, value = short_form_icon(node) || long_form_icon(node)
          return unless pair

          names = approved_icons
          return if names.empty?
          return if names.include?(value.value)

          add_offense(value, message: format(MSG, name: value.value))
        end

        private

        def approved_icons
          @approved_icons ||= configured_icons | icons_from_file
        end

        def configured_icons
          Array(cop_config["ApprovedIcons"]).map(&:to_s)
        end

        # Parses `NAME = %w[…]` out of a plain file. Reading the constant rather
        # than loading it keeps the cop free of the application it lints.
        #
        # The path resolves against the directory of the config that set it, the
        # same base RuboCop uses for Include/Exclude, so the set is found whatever
        # directory the run was started from.
        def icons_from_file
          path = approved_icons_path
          return [] if path.nil? || !File.exist?(path)

          constant = cop_config.fetch("ApprovedIconsConstant", "APPROVED_ICONS")
          body = File.read(path)[/#{Regexp.escape(constant)}\s*=\s*%w\[(.*?)\]/m, 1]
          body.to_s.split
        end

        def approved_icons_path
          configured = cop_config["ApprovedIconsFile"]
          return nil if configured.nil? || configured.empty?

          File.absolute_path(configured, config.base_dir_for_path_parameters)
        end
      end
    end
  end
end
