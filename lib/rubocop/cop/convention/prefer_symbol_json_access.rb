# frozen_string_literal: true

module RuboCop
  module Cop
    module Convention
      # Enforces symbol access over string access for hash/JSON data.
      #
      # This cop is STRICT - it flags ALL string access patterns except for known
      # false positive cases.
      # The solution is to normalize data at the boundary using `.with_indifferent_access`
      # and then use symbol access consistently.
      #
      # @example
      #   # bad
      #   data["key"]
      #   record["name"]
      #
      #   # good
      #   data[:key]
      #   record[:name]
      #
      # @example Boundary normalization (where data enters)
      #   # good - normalize at the boundary, then use symbols
      #   data = JSON.parse(response.body).with_indifferent_access
      #   data[:key]
      #
      #   # good - normalize in model accessor
      #   def enrichment_data
      #     super&.with_indifferent_access
      #   end
      #
      class PreferSymbolJsonAccess < Base
        extend AutoCorrector

        MSG = "Use symbol access `[:%<key>s]` instead of string access `[\"%<key>s\"]`. " \
              "Normalize data with `.with_indifferent_access` at the boundary."

        # HTTP header names that should use string access
        HTTP_HEADERS = %w[
          Authorization
          Content-Type
          Accept
          User-Agent
          X-API-Key
          X-CSRF-Token
          Turbo-Frame
        ].freeze

        # Rack environment variables that require string access
        RACK_ENV_VARS = %w[
          HTTP_ACCEPT_LANGUAGE
          HTTP_STRIPE_SIGNATURE
          warden
        ].freeze

        # External API response fields that typically use string access
        EXTERNAL_API_FIELDS = %w[
          SubscribeURL
          Message
          access_token
          refresh_token
          expires_in
          error
          error_description
          id
          Id
          email
          mail
          userPrincipalName
          displayName
          firstName
          lastName
          userName
          externalId
        ].freeze

        # JavaScript/DOM properties that use string access
        DOM_PROPERTIES = %w[
          className
          textContent
          innerHTML
          href
          src
          alt
          role
          classList
          x
          y
          width
          height
          left
          right
          top
          bottom
          title
          id
          name
          value
          type
          checked
          disabled
        ].freeze

        def_node_matcher :string_hash_access?, <<~PATTERN
          (send _ :[] (str $_))
        PATTERN

        def_node_matcher :conditional_access?, <<~PATTERN
          (or
            (send _ :[] (sym $_))
            (send _ :[] (str $_))
          )
        PATTERN

        def_node_matcher :rake_task_access?, <<~PATTERN
          (send
            (const
              (const nil? :Rake) :Task) :[]
            (str $_))
        PATTERN

        def_node_matcher :request_env_access?, <<~PATTERN
          (send
            (send
              (send nil? :request) :env) :[]
            (str $_))
        PATTERN

        def_node_matcher :request_headers_access?, <<~PATTERN
          (send
            (send
              (send nil? :request) :headers) :[]
            (str $_))
        PATTERN

        def_node_matcher :params_access?, <<~PATTERN
          (send
            (send nil? :params) :[]
            (str $_))
        PATTERN

        def on_send(node)
          string_hash_access?(node) do |key|
            # Skip if key contains spaces or special chars (not symbol-convertible)
            return if key.match?(/[\s\-\.]/)

            # Skip ENV access - ENV only accepts string keys
            return if env_access?(node)

            # Skip Rake task access
            return if rake_task_access?(node)

            # Skip request.env access
            return if request_env_access?(node, key)

            # Skip request.headers access
            return if request_headers_access?(node, key)

            # Skip params access (often comes from external sources)
            return if params_access?(node)

            # Skip conditional access patterns (e.g., value[:key] || value["key"])
            return if part_of_conditional_access?(node)

            # Skip known external API fields
            return if EXTERNAL_API_FIELDS.include?(key)

            # Skip DOM properties
            return if DOM_PROPERTIES.include?(key)

            # Skip if receiver might be external data
            return if likely_external_data?(node)

            add_offense(node.loc.selector, message: format(MSG, key: key)) do |corrector|
              corrector.replace(node.first_argument.loc.expression, ":#{key}")
            end
          end
        end

        private

        def env_access?(node)
          receiver = node.receiver
          receiver&.const_type? && receiver.const_name == "ENV"
        end

        def request_env_access?(node, key)
          request_env_access?(node) && RACK_ENV_VARS.include?(key)
        end

        def request_headers_access?(node, key)
          request_headers_access?(node) && HTTP_HEADERS.include?(key)
        end

        def part_of_conditional_access?(node)
          parent = node.parent
          return false unless parent&.or_type?

          # Check if this is part of a pattern like: value[:key] || value["key"]
          left = parent.children[0]
          right = parent.children[1]

          # Both sides should be hash access
          return false unless left&.send_type? && right&.send_type?
          return false unless left.method_name == :[] && right.method_name == :[]

          # Same receiver
          return false unless same_receiver?(left.receiver, right.receiver)

          # One uses symbol, other uses string for the same key
          left_key = extract_key(left)
          right_key = extract_key(right)

          left_key && right_key && left_key.to_s == right_key.to_s &&
            ((left.first_argument.sym_type? && right.first_argument.str_type?) ||
             (left.first_argument.str_type? && right.first_argument.sym_type?))
        end

        def same_receiver?(receiver1, receiver2)
          return true if receiver1.nil? && receiver2.nil?
          return false if receiver1.nil? || receiver2.nil?

          if receiver1.send_type? && receiver2.send_type?
            receiver1.method_name == receiver2.method_name &&
              same_receiver?(receiver1.receiver, receiver2.receiver)
          elsif receiver1.lvar_type? && receiver2.lvar_type?
            receiver1.node_parts == receiver2.node_parts
          else
            receiver1 == receiver2
          end
        end

        def extract_key(node)
          return nil unless node.send_type? && node.method_name == :[]

          arg = node.first_argument
          if arg.sym_type?
            arg.value.to_s
          elsif arg.str_type?
            arg.value
          end
        end

        def likely_external_data?(node)
          receiver = node.receiver
          return false unless receiver

          # Check for common external data variable names
          if receiver.lvar_type?
            var_name = receiver.node_parts.first.to_s
            return true if var_name.match?(/response|request|params|headers|env|data|result|body|payload|message|event|attributes|options|config|settings/)
          end

          # Check for method calls that likely return external data
          if receiver.send_type?
            method_name = receiver.method_name.to_s
            return true if method_name.match?(/parse|load|fetch|get|read|receive|decode/)
          end

          false
        end
      end
    end
  end
end
