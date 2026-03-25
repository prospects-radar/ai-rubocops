# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Prevents database queries in Phlex components
      #
      # Components should receive all data via initialization.
      # Querying the database directly breaks separation of concerns
      # and can cause N+1 queries and performance issues.
      #
      # @example
      #   # bad
      #   class UserCard < BaseComponent
      #     def view_template
      #       div do
      #         User.where(active: true).each do |user|
      #           p { user.name }
      #         end
      #       end
      #     end
      #   end
      #
      #   # good
      #   class UserCard < BaseComponent
      #     def initialize(users:)
      #       @users = users
      #     end
      #
      #     def view_template
      #       div do
      #         @users.each do |user|
      #           p { user.name }
      #         end
      #       end
      #     end
      #   end
      #
      class NoComponentDatabaseQueries < Base
        MSG = "Avoid database queries in components. Pass data via initialization instead."

        def_node_matcher :in_component_class?, <<~PATTERN
          {
            (class (const nil? $_) (const (const nil? :Components) :GlassMorph) ...)
            (class (const nil? $_) (const ... :BaseComponent) ...)
          }
        PATTERN

        def on_send(node)
          return unless in_component_file?
          return unless query_methods.include?(node.method_name)
          return unless likely_model_query?(node)

          add_offense(node)
        end

        private

        def query_methods
          cop_config.fetch("QueryMethods", %w[
            where find find_by all first last pluck count exists? select joins includes
            eager_load preload references group having order limit offset distinct
            unscoped readonly lock create create! update update_all delete delete_all
            destroy destroy_all
          ]).map(&:to_sym)
        end

        def in_component_file?
          processed_source.path.include?("app/components/")
        end

        def likely_model_query?(node)
          # Check if receiver is a constant (likely a model class)
          # e.g., User.where(...) or Company.all
          receiver = node.receiver
          return false unless receiver

          # Const receiver (Model.method)
          if receiver.const_type?
            # Exclude common false positives:
            # - ALL_CAPS constants (usually arrays/hashes like SCORE_COLORS, CLASSIFICATION_SYSTEMS)
            # - Known non-model constants (I18n, Array, Hash, etc.)
            const_name = receiver.const_name
            return false if const_name.match?(/^[A-Z_]+$/) # All caps = likely a constant, not a model
            return false if %w[Array Hash Set String Integer Float Time Date DateTime I18n].include?(const_name)

            return true
          end

          # Self receiver in component (self.class.method - less common)
          false
        end
      end
    end
  end
end
