# frozen_string_literal: true

module RuboCop
  module Cop
    module Cucumber
      # Detects silent rescue blocks around database operations in Cucumber hooks.
      #
      # Silently rescuing database errors (especially around cleanup operations
      # like DatabaseCleaner, disable_referential_integrity, truncation) hides
      # failures that cause state leaks between test scenarios.
      #
      # @example Bad - Silent rescue around DB cleanup
      #   # bad
      #   After('@javascript') do
      #     begin
      #       ActiveRecord::Base.connection.disable_referential_integrity do
      #         DatabaseCleaner.clean
      #       end
      #     rescue StandardError => e
      #       Rails.logger.warn "Could not clean: #{e.message}"
      #       DatabaseCleaner.clean  # Fallback that also silently fails
      #     end
      #   end
      #
      # @example Good - CASCADE truncation without rescue
      #   # good
      #   After('@javascript') do
      #     tables = ActiveRecord::Base.connection.tables - SEED_TABLES
      #     ActiveRecord::Base.connection.execute(
      #       "TRUNCATE TABLE #{tables.map { |t| %(\"#{t}\") }.join(', ')} RESTART IDENTITY CASCADE"
      #     )
      #   end
      #
      class NoSilentDatabaseRescue < Base
        MSG = "Avoid silently rescuing database operations in hooks. " \
              "Use CASCADE truncation or let errors surface. " \
              "Silent rescue around `%<method>s` hides state leaks between tests."

        # Database-related method names that should not be silently rescued
        DB_METHODS = %i[
          clean
          truncate
          disable_referential_integrity
          execute
          delete_all
          destroy_all
        ].to_set.freeze

        def on_resbody(node)
          return unless in_cucumber_support_file?

          # Check if the rescue body is in a hook context (After/Before block)
          return unless inside_hook_block?(node)

          # Find database calls within the begin block that this rescue covers
          begin_node = node.parent
          return unless begin_node&.kwbegin_type? || begin_node&.rescue_type?

          # Check the body of the begin/rescue for DB operations
          body = begin_node.rescue_type? ? begin_node.body : begin_node

          return unless body

          db_method = find_database_method(body)
          return unless db_method

          add_offense(node, message: format(MSG, method: db_method))
        end

        private

        def in_cucumber_support_file?
          path = processed_source.path
          path.include?("features/support/")
        end

        def inside_hook_block?(node)
          node.each_ancestor(:block).any? do |block|
            method_name = block.method_name
            %i[After Before].include?(method_name)
          end
        end

        def find_database_method(node)
          return nil unless node

          if node.send_type?
            method_name = node.method_name
            return method_name.to_s if DB_METHODS.include?(method_name)
          end

          # Recursively check children
          node.each_child_node do |child|
            result = find_database_method(child)
            return result if result
          end

          nil
        end
      end
    end
  end
end
