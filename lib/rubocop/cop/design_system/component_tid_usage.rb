# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Enforces use of `tid` helper for test IDs in components
      #
      # @example
      #   # bad
      #   div(data: { testid: "submit-button" })
      #   div(data: { test_id: "submit-button" })
      #   button(**{ "data-testid": "cancel-btn" })
      #   div(**root_attributes(test_id: "my-element"))
      #
      #   # good
      #   div(**tid("submit-button"))
      #   button(**tid("cancel-btn"))
      #   div(**root_attributes) # test_id handled by tid separately
      #
      class ComponentTidUsage < RuboCop::Cop::Base
        include RangeHelp
        extend AutoCorrector

        MSG = "Use `tid` helper for test IDs: `**tid(\"element-name\")` instead of manual data attributes"

        def_node_matcher :manual_testid_in_data_hash?, <<~PATTERN
          (pair (sym :data) (hash <(pair (sym {:testid :test_id}) $_) ...>))
        PATTERN

        def_node_matcher :manual_testid_attribute?, <<~PATTERN
          (pair (sym :data_testid) $_)
        PATTERN

        def_node_matcher :test_id_in_root_attributes?, <<~PATTERN
          (send nil? :root_attributes (hash <(pair (sym :test_id) $_) ...>))
        PATTERN

        def_node_matcher :quoted_testid_key?, <<~PATTERN
          (pair (str "data-testid") $_)
        PATTERN

        def_node_search :hash_splat_tid?, <<~PATTERN
          (kwsplat (send nil? :tid ...))
        PATTERN

        def on_send(node)
          return unless in_component_or_view_file?

          # Special handling for root_attributes calls
          if node.method_name == :root_attributes
            check_root_attributes_for_test_id(node)
            return
          end

          return unless phlex_element?(node)

          # Check if arguments already use tid helper
          return if hash_splat_tid?(node)

          # Check for manual data-testid usage
          node.arguments.each do |arg|
            next unless arg.hash_type?

            check_hash_for_manual_testid(arg)

            # Also check nested hashes (e.g., html: { data: { testid: ... } })
            check_nested_hashes(arg, 0, node)
          end
        end

        private

        def in_component_or_view_file?
          path = processed_source.path
          path.include?("app/components/") || path.include?("app/views/")
        end

        def phlex_element?(node)
          # Common Phlex element methods and Rails helpers that can have data attributes
          %i[
            div span button a p h1 h2 h3 h4 h5 h6
            form input select textarea label
            ul li table tr td th
            form_with form_for link_to button_to
            render_component render
          ].include?(node.method_name) ||
          # Also check for GlassMorph component calls (capitalized methods)
          node.method_name.to_s.match?(/^[A-Z]/)
        end

        def check_root_attributes_for_test_id(node)
          return unless node.arguments.first&.hash_type?

          hash_node = node.arguments.first
          hash_node.pairs.each do |pair|
            next unless pair.key.sym_type? && pair.key.value == :test_id

            add_offense(pair, message: "Remove test_id from root_attributes and use tid helper separately") do |corrector|
              # Remove the test_id pair from root_attributes
              remove_pair_with_comma(corrector, pair)

              # We can't automatically add tid() because we don't know where to insert it
              # The developer needs to add **tid(...) manually
            end
          end
        end

        def check_nested_hashes(hash_node, depth = 0, parent_send_node = nil)
          # Don't go too deep to avoid infinite recursion
          return if depth > 3

          hash_node.pairs.each do |pair|
            # Look for html: { ... } or similar nested hashes
            if pair.value.hash_type?
              check_hash_for_manual_testid_nested(pair.value, parent_send_node || find_parent_send_node(hash_node))
              # Recursively check deeper nesting
              check_nested_hashes(pair.value, depth + 1, parent_send_node || find_parent_send_node(hash_node))
            end
          end
        end

        def check_hash_for_manual_testid_nested(hash_node, parent_send_node)
          hash_node.pairs.each do |pair|
            # Check for data: { testid: "..." } or data: { test_id: "..." }
            manual_testid_in_data_hash?(pair) do |value|
              add_offense(pair) do |corrector|
                autocorrect_nested_data_hash(corrector, pair, value, parent_send_node)
              end
            end
          end
        end

        def find_parent_send_node(node)
          # Walk up the AST to find the parent send node (e.g., form_with)
          current = node
          while current
            return current if current.send_type?
            current = current.parent
          end
          nil
        end

        def check_hash_for_manual_testid(hash_node)
          hash_node.pairs.each do |pair|
            # Check for data: { testid: "..." } or data: { test_id: "..." }
            manual_testid_in_data_hash?(pair) do |value|
              add_offense(pair) do |corrector|
                autocorrect_data_hash(corrector, pair, value)
              end
            end

            # Check for data_testid: "..."
            manual_testid_attribute?(pair) do |value|
              add_offense(pair) do |corrector|
                autocorrect_attribute(corrector, pair, value)
              end
            end

            # Check for :"data-testid": "..." by looking at the key directly
            if pair.key.sym_type? && pair.key.value == :"data-testid"
              add_offense(pair) do |corrector|
                autocorrect_attribute(corrector, pair, pair.value)
              end
            end

            # Check for "data-testid": "..." with quoted key
            quoted_testid_key?(pair) do |value|
              add_offense(pair) do |corrector|
                autocorrect_attribute(corrector, pair, value)
              end
            end
          end
        end

        def autocorrect_data_hash(corrector, pair, value)
          # pair is the `data: { testid: "...", ... }` pair
          # value is the string node for the testid value
          data_hash = pair.children[1] # The hash node inside data: { ... }
          testid_pair = data_hash.pairs.find { |p| p.key.value == :testid || p.key.value == :test_id }
          tid_value = value.source
          parent_hash = pair.parent

          if data_hash.pairs.size == 1
            # data: { testid: "..." } is the only content - remove entire data pair
            remove_pair_with_comma(corrector, pair)
          else
            # data hash has other keys - only remove testid pair from inside
            remove_pair_with_comma(corrector, testid_pair)
          end

          # Insert **tid at beginning of parent hash arguments
          corrector.insert_before(parent_hash.pairs.first.loc.expression, "**tid(#{tid_value}), ")
        end

        def remove_pair_with_comma(corrector, pair)
          range = pair.loc.expression

          # Check for trailing comma and whitespace
          source = processed_source.raw_source
          end_pos = range.end_pos

          # Look for comma after the pair
          if source[end_pos] == ","
            # Include comma and following whitespace
            while source[end_pos + 1] =~ /\s/
              end_pos += 1
            end
            extended_range = range.with(end_pos: end_pos + 1)
            corrector.remove(extended_range)
          elsif range.begin_pos > 0 && source[range.begin_pos - 1] =~ /[\s,]/
            # Look for leading comma/whitespace
            begin_pos = range.begin_pos
            while begin_pos > 0 && source[begin_pos - 1] =~ /[\s]/
              begin_pos -= 1
            end
            if begin_pos > 0 && source[begin_pos - 1] == ","
              begin_pos -= 1
            end
            extended_range = range.with(begin_pos: begin_pos)
            corrector.remove(extended_range)
          else
            corrector.remove(range)
          end
        end

        def autocorrect_attribute(corrector, pair, value)
          # Replace data_testid: "..." with **tid("...")
          tid_value = value.source
          corrector.replace(pair.loc.expression, "**tid(#{tid_value})")
        end

        def autocorrect_nested_data_hash(corrector, pair, value, parent_send_node)
          # pair is the `data: { testid: "...", ... }` pair inside html: { ... }
          # value is the string node for the testid value
          # parent_send_node is the form_with or similar Rails helper call

          data_hash = pair.children[1] # The hash node inside data: { ... }
          testid_pair = data_hash.pairs.find { |p| p.key.value == :testid || p.key.value == :test_id }
          tid_value = value.source

          # Remove testid from the nested data hash
          if data_hash.pairs.size == 1
            # data: { testid: "..." } is the only content - remove entire data pair
            remove_pair_with_comma(corrector, pair)
          else
            # data hash has other keys - only remove testid pair from inside
            remove_pair_with_comma(corrector, testid_pair)
          end

          # Add **tid(...) to the parent send node's arguments
          if parent_send_node
            insert_tid_in_send_node(corrector, parent_send_node, tid_value)
          end
        end

        def insert_tid_in_send_node(corrector, send_node, tid_value)
          # Find the first hash argument in the send node
          first_hash = send_node.arguments.find(&:hash_type?)

          if first_hash
            # Insert **tid(...) at the beginning of the first hash
            corrector.insert_before(first_hash.loc.expression, "**tid(#{tid_value}), ")
          else
            # No hash arguments - add **tid(...) as a new hash argument
            # Insert after the last argument or after the method name if no arguments
            if send_node.arguments.any?
              last_arg = send_node.arguments.last
              corrector.insert_after(last_arg.loc.expression, ", **tid(#{tid_value})")
            else
              # No arguments at all - insert after method name
              corrector.insert_after(send_node.loc.selector, "(#{tid_value})")
            end
          end
        end
      end
    end
  end
end
