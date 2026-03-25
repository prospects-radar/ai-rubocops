# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Detects hard-coded HTML patterns that should use GlassMorph components instead.
      #
      # This cop identifies common HTML patterns (buttons, badges, cards, etc.)
      # that should be replaced with corresponding GlassMorph Atoms, Molecules, or Organisms.
      #
      # @example
      #   # bad - hard-coded button
      #   button(class: "btn btn-primary") { "Click me" }
      #   a(href: "#", class: "btn btn-success") { "Submit" }
      #
      #   # good - use GlassMorph component
      #   render Components::GlassMorph::Atoms::Button.new(variant: :primary) { "Click me" }
      #
      #   # bad - hard-coded badge
      #   span(class: "badge bg-primary") { "New" }
      #
      #   # good - use GlassMorph component
      #   render Components::GlassMorph::Atoms::Badge.new(text: "New", variant: :primary)
      #
      #   # bad - hard-coded card
      #   div(class: "card") do
      #     div(class: "card-body") { "Content" }
      #   end
      #
      #   # good - use GlassMorph component
      #   render Components::GlassMorph::Molecules::Card.new { "Content" }
      #
      class NoHardcodedHtmlComponents < Base
        extend AutoCorrector

        MSG_BUTTON = "Use Components::GlassMorph::Atoms::Button instead of hard-coded button/link with btn classes"
        MSG_BADGE = "Use Components::GlassMorph::Atoms::Badge instead of hard-coded span/div with badge classes"
        MSG_CARD = "Use Components::GlassMorph::Molecules::Card instead of hard-coded div with card classes"
        MSG_ALERT = "Use Components::GlassMorph::Molecules::Alert instead of hard-coded div with alert classes"
        MSG_MODAL = "Use Components::GlassMorph::Organisms::Modal instead of hard-coded div with modal classes"
        MSG_ICON = "Use Components::GlassMorph::Atoms::Icon instead of hard-coded <i> tags with icon classes"
        MSG_SVG_ICON = "Use Components::GlassMorph::Atoms::Icon instead of inline <svg> icon elements"
        MSG_SPINNER = "Use Components::GlassMorph::Atoms::Spinner instead of hard-coded spinner HTML"
        MSG_PAGINATION = "Use Components::GlassMorph::Organisms::Pagination instead of hard-coded pagination HTML"
        MSG_TABLE = "Use Components::GlassMorph::Molecules::Table instead of hard-coded table with Bootstrap classes"
        MSG_FORM_INPUT = "Use Components::GlassMorph::Atoms::Input instead of hard-coded input with form-control classes"
        MSG_FORM_SELECT = "Use Components::GlassMorph::Atoms::Select instead of hard-coded select with form-select classes"
        MSG_FORM_CHECKBOX = "Use Components::GlassMorph::Atoms::Checkbox instead of hard-coded checkbox HTML"
        MSG_FORM_RADIO = "Use Components::GlassMorph::Atoms::Radio instead of hard-coded radio HTML"
        MSG_BREADCRUMB = "Use Components::GlassMorph::Molecules::Breadcrumb instead of hard-coded breadcrumb HTML"
        MSG_NAVBAR = "Use Components::GlassMorph::Organisms::Navbar instead of hard-coded navbar HTML"
        MSG_DROPDOWN = "Use Components::GlassMorph::Molecules::Dropdown instead of hard-coded dropdown HTML"
        MSG_TOOLTIP = "Use Components::GlassMorph::Atoms::Tooltip instead of hard-coded tooltip attributes"
        MSG_TAB = "Use Components::GlassMorph::Molecules::Tabs instead of hard-coded tab HTML"
        MSG_ACCORDION = "Use Components::GlassMorph::Molecules::Accordion instead of hard-coded accordion HTML"

        # Pattern definitions for common HTML components
        # These patterns look for Bootstrap classes, not custom application classes
        BUTTON_CLASSES = /\bbtn\s+(btn-|bg-)/  # btn btn-primary, not just "btn"
        BADGE_CLASSES = /\bbadge\s+(bg-|text-)/  # badge bg-primary, not custom badge-*
        CARD_CLASSES = /^card$|^card\s|card\s+(shadow|border|mb-|mt-|p-|bg-)/  # "card" alone or with Bootstrap modifiers, not "timeline-event-card"
        ALERT_CLASSES = /\balert\s+alert-/  # alert alert-danger
        MODAL_CLASSES = /\bmodal\s+(fade|show|dialog)/  # Bootstrap modal classes
        ICON_CLASSES = /\b(fa|fas|far|fab|fal|bi)\s+(fa-|bi-)/  # FontAwesome or Bootstrap Icons with icon name
        SPINNER_CLASSES = /\bspinner-(border|grow)\b/  # Bootstrap spinner classes
        PAGINATION_CLASSES = /\bpagination\b/
        TABLE_CLASSES = /\btable\s+(table-|bg-|border)/  # table with Bootstrap modifiers
        FORM_CONTROL_CLASSES = /\bform-control\b/
        FORM_SELECT_CLASSES = /\bform-select\b/
        FORM_CHECK_CLASSES = /\bform-check\b/
        BREADCRUMB_CLASSES = /\bbreadcrumb\b/
        NAVBAR_CLASSES = /\bnavbar\s+(navbar-|bg-|fixed-|sticky-)/  # Bootstrap navbar with modifiers, not just "navbar"
        DROPDOWN_CLASSES = /\bdropdown-(menu|toggle|item)\b/  # Bootstrap dropdown classes
        TAB_CLASSES = /\bnav-tabs\b|\btab-pane\b/
        ACCORDION_CLASSES = /\baccordion-(item|header|body|button)\b/  # Bootstrap accordion classes

        # Tooltip/popover data attributes
        TOOLTIP_ATTRS = /data-bs-toggle.*tooltip|data-bs-toggle.*popover/

        def on_send(node)
          return unless phlex_html_method?(node)
          return if whitelisted_context?(node)

          check_for_button(node)
          check_for_badge(node)
          check_for_card(node)
          check_for_alert(node)
          check_for_modal(node)
          check_for_icon(node)
          check_for_svg_icon(node)
          check_for_spinner(node)
          check_for_pagination(node)
          check_for_table(node)
          check_for_form_controls(node)
          check_for_breadcrumb(node)
          check_for_navbar(node)
          check_for_dropdown(node)
          check_for_tooltip(node)
          check_for_tabs(node)
          check_for_accordion(node)
        end

        private

        # Check if this is a Phlex HTML DSL method (div, span, button, etc.)
        def phlex_html_method?(node)
          return false unless node.method_name.match?(/^[a-z_]+$/)
          return false if node.receiver

          # Common Phlex/HTML methods
          %i[div span button a i svg ul ol li nav table tr td th input select textarea label form
             h1 h2 h3 h4 h5 h6 p strong em].include?(node.method_name)
        end

        # Check if we're in a whitelisted context where hard-coded HTML is allowed
        def whitelisted_context?(node)
          # Allow in base components, styleguide, or legacy components
          path = processed_source.file_path
          path.include?("base_component.rb") ||
            path.include?("styleguide/") ||
            path.include?("app/components/preline/") ||
            path.include?("legacy/")
        end

        # Extract class attribute value from Phlex method call.
        # Handles both plain strings ("btn btn-primary") and interpolated strings
        # ("btn btn-primary #{extra}") by joining only the literal str parts.
        def class_value(node)
          return nil unless node.arguments.any?

          # Look for hash argument with :class key
          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return nil unless hash_arg

          class_pair = hash_arg.pairs.find { |pair| pair.key.value == :class }
          return nil unless class_pair

          value_node = class_pair.value

          if value_node.str_type?
            value_node.value
          elsif value_node.dstr_type?
            # Join only the literal string children; dynamic parts (#{...}) are ignored
            # but the static portions are enough to detect Bootstrap class patterns.
            value_node.children.select(&:str_type?).map(&:value).join
          end
        end

        # Extract data attribute hash from Phlex method call
        def data_attrs(node)
          return nil unless node.arguments.any?

          hash_arg = node.arguments.find { |arg| arg.hash_type? }
          return nil unless hash_arg

          data_pair = hash_arg.pairs.find { |pair| pair.key.value == :data }
          return nil unless data_pair

          data_pair.value if data_pair.value.hash_type?
        end

        def check_for_button(node)
          classes = class_value(node)
          return unless classes

          if (node.method_name == :button || node.method_name == :a) && classes.match?(BUTTON_CLASSES)
            add_offense(node, message: MSG_BUTTON)
          end
        end

        def check_for_badge(node)
          classes = class_value(node)
          return unless classes

          if (node.method_name == :span || node.method_name == :div) && classes.match?(BADGE_CLASSES)
            add_offense(node, message: MSG_BADGE) do |corrector|
              autocorrect_badge(corrector, node, classes)
            end
          end
        end

        def check_for_card(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :div && classes.match?(CARD_CLASSES)
            add_offense(node, message: MSG_CARD)
          end
        end

        def check_for_alert(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :div && classes.match?(ALERT_CLASSES)
            add_offense(node, message: MSG_ALERT) do |corrector|
              autocorrect_alert(corrector, node, classes)
            end
          end
        end

        def check_for_modal(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :div && classes.match?(MODAL_CLASSES)
            add_offense(node, message: MSG_MODAL)
          end
        end

        def check_for_icon(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :i && classes.match?(ICON_CLASSES)
            add_offense(node, message: MSG_ICON) do |corrector|
              autocorrect_icon(corrector, node, classes)
            end
          end
        end

        def check_for_svg_icon(node)
          return unless node.method_name == :svg
          return if svg_data_visualization?(node)

          # Flag inline svg() calls that look like icons — these should use the Icon atom
          add_offense(node, message: MSG_SVG_ICON)
        end

        # Detect SVGs that are data visualizations, brand logos, or charts (not icons)
        # These should be marked with rubocop:disable in the source
        def svg_data_visualization?(node)
          false
        end

        def enclosing_method_name(node)
          node.each_ancestor(:def).first&.method_name&.to_s
        end

        def check_for_spinner(node)
          classes = class_value(node)
          return unless classes

          if (node.method_name == :div || node.method_name == :span) && classes.match?(SPINNER_CLASSES)
            add_offense(node, message: MSG_SPINNER) do |corrector|
              autocorrect_spinner(corrector, node, classes)
            end
          end
        end

        def check_for_pagination(node)
          classes = class_value(node)
          return unless classes

          if (node.method_name == :nav || node.method_name == :ul) && classes.match?(PAGINATION_CLASSES)
            add_offense(node, message: MSG_PAGINATION)
          end
        end

        def check_for_table(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :table && classes.match?(TABLE_CLASSES)
            add_offense(node, message: MSG_TABLE)
          end
        end

        def check_for_form_controls(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :input && classes.match?(FORM_CONTROL_CLASSES)
            add_offense(node, message: MSG_FORM_INPUT)
          elsif node.method_name == :select && classes.match?(FORM_SELECT_CLASSES)
            add_offense(node, message: MSG_FORM_SELECT)
          elsif (node.method_name == :input || node.method_name == :div) && classes.match?(FORM_CHECK_CLASSES)
            # Determine if checkbox or radio based on type attribute or context
            add_offense(node, message: MSG_FORM_CHECKBOX)
          end
        end

        def check_for_breadcrumb(node)
          classes = class_value(node)
          return unless classes

          if (node.method_name == :nav || node.method_name == :ol) && classes.match?(BREADCRUMB_CLASSES)
            add_offense(node, message: MSG_BREADCRUMB)
          end
        end

        def check_for_navbar(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :nav && classes.match?(NAVBAR_CLASSES)
            add_offense(node, message: MSG_NAVBAR)
          end
        end

        def check_for_dropdown(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :div && classes.match?(DROPDOWN_CLASSES)
            add_offense(node, message: MSG_DROPDOWN)
          end
        end

        def check_for_tooltip(node)
          data = data_attrs(node)
          return unless data

          # Convert data hash to string representation for pattern matching
          data_str = data.source
          if data_str.match?(TOOLTIP_ATTRS)
            add_offense(node, message: MSG_TOOLTIP)
          end
        end

        def check_for_tabs(node)
          classes = class_value(node)
          return unless classes

          if (node.method_name == :ul || node.method_name == :div) && classes.match?(TAB_CLASSES)
            add_offense(node, message: MSG_TAB)
          end
        end

        def check_for_accordion(node)
          classes = class_value(node)
          return unless classes

          if node.method_name == :div && classes.match?(ACCORDION_CLASSES)
            add_offense(node, message: MSG_ACCORDION)
          end
        end

        # Autocorrect methods

        def autocorrect_icon(corrector, node, classes)
          icon_name, icon_style = extract_icon_name(classes)
          return unless icon_name

          # Extract any additional classes (non-icon classes like me-1, text-lg, etc.)
          # Remove icon-related parts: bi, fa, fas, far, fab, fal, and icon names
          other_classes = classes.split.reject do |cls|
            cls.match?(/^(bi|fa|fas|far|fab|fal)$/) || cls.match?(/^(bi-|fa-)/)
          end

          # Build the replacement
          params = [ "name: \"#{icon_name}\"", "style: :#{icon_style}" ]
          params << "class: \"#{other_classes.join(' ')}\"" if other_classes.any?

          replacement = "render Components::GlassMorph::Atoms::Icon.new(#{params.join(', ')})"

          corrector.replace(node, replacement)
        end

        def autocorrect_badge(corrector, node, classes)
          variant = extract_badge_variant(classes)
          text_content = extract_simple_text_content(node)

          return unless variant

          # Extract non-badge classes (like me-2, ms-1, etc.)
          other_classes = classes.split.reject do |cls|
            cls.match?(/badge/) || cls.match?(/bg-[a-z]+/) || cls.match?(/text-[a-z]+/)
          end

          # Build replacement based on whether there's simple text content
          params = [ "variant: :#{variant}" ]
          params << "class: \"#{other_classes.join(' ')}\"" if other_classes.any?

          if text_content && !has_block?(node)
            # Simple inline content: span(class: "badge bg-success") { "Active" }
            # Convert to: render Badge.new(text: "Active", variant: :success)
            params.unshift("text: #{text_content.inspect}")
            replacement = "render Components::GlassMorph::Atoms::Badge.new(#{params.join(', ')})"
          else
            # Block content or complex content: preserve the block
            replacement = "render Components::GlassMorph::Atoms::Badge.new(#{params.join(', ')})"
          end

          corrector.replace(node, replacement)
        end

        def autocorrect_spinner(corrector, node, classes)
          size = classes.include?("spinner-border-sm") ? :sm : :md
          variant = extract_spinner_variant(classes)

          # Extract non-spinner classes (like d-none, me-2, etc.)
          other_classes = classes.split.reject do |cls|
            cls.match?(/spinner-(border|grow)/) || cls.match?(/text-[a-z]+/)
          end

          params = [ "size: :#{size}" ]
          params << "variant: :#{variant}" if variant
          params << "class: \"#{other_classes.join(' ')}\"" if other_classes.any?

          replacement = "render Components::GlassMorph::Atoms::Spinner.new(#{params.join(', ')})"

          corrector.replace(node, replacement)
        end

        def autocorrect_alert(corrector, node, classes)
          variant = extract_alert_variant(classes)
          return unless variant

          # Check if there's a block
          if has_block?(node)
            # For alerts with blocks, we need more complex handling
            # For now, just do simple replacement
            replacement = "render Components::GlassMorph::Molecules::Alert.new(variant: :#{variant})"
          else
            text_content = extract_text_content(node)
            replacement = if text_content
              "render Components::GlassMorph::Molecules::Alert.new(message: #{text_content.inspect}, variant: :#{variant})"
            else
              "render Components::GlassMorph::Molecules::Alert.new(variant: :#{variant})"
            end
          end

          corrector.replace(node, replacement)
        end

        # Helper methods for autocorrection

        def extract_icon_name(classes)
          # Bootstrap Icons: bi bi-cpu -> ["cpu", "bootstrap"]
          if classes =~ /\bbi\s+bi-([a-z0-9-]+)/
            icon_name = Regexp.last_match(1)
            return [ icon_name, "bootstrap" ]
          end

          # FontAwesome: fa fa-user, fas fa-user, etc -> ["user", "solid"]
          if classes =~ /\b(fa|fas|far|fab|fal)\s+fa-([a-z0-9-]+)/
            style_map = { "fa" => "solid", "fas" => "solid", "far" => "regular", "fab" => "brands", "fal" => "light" }
            style = style_map[Regexp.last_match(1)] || "solid"
            icon_name = Regexp.last_match(2)
            return [ icon_name, style ]
          end

          nil
        end

        def extract_badge_variant(classes)
          # badge bg-primary -> :primary
          # badge bg-success -> :success
          if classes =~ /bg-([a-z]+)/
            Regexp.last_match(1)
          else
            "secondary" # default
          end
        end

        def extract_spinner_variant(classes)
          # spinner-border text-primary -> :primary
          if classes =~ /text-([a-z]+)/
            Regexp.last_match(1)
          else
            nil
          end
        end

        def extract_alert_variant(classes)
          # alert alert-danger -> :danger
          # alert alert-warning -> :warning
          if classes =~ /alert-([a-z]+)/
            Regexp.last_match(1)
          else
            "info" # default
          end
        end

        def extract_simple_text_content(node)
          # Try to extract simple text content from inline blocks like { "text" }
          return nil unless node.block_node

          block = node.block_node
          return nil unless block.body

          # If it's a simple string literal in block: { "text" }
          if block.body.str_type?
            return block.body.value
          end

          nil
        end

        def has_block?(node)
          node.block_node&.body
        end
      end
    end
  end
end
