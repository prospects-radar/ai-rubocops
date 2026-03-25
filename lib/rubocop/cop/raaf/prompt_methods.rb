# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Enforces RAAF prompt method naming: def system and def user,
      # not custom render methods (DEC-019).
      #
      # RAAF prompts must use standard method names for consistency.
      #
      # @example
      #   # bad
      #   class MyPrompt < RAAF::DSL::Prompts::Base
      #     def prompt  # Wrong method name
      #       "..."
      #     end
      #
      #     def render  # Wrong method name
      #       "..."
      #     end
      #   end
      #
      #   # good
      #   class MyPrompt < RAAF::DSL::Prompts::Base
      #     def system
      #       "You are an AI assistant..."
      #     end
      #
      #     def user
      #       "Please analyze the following..."
      #     end
      #   end
      #
      class PromptMethods < Base
        extend AutoCorrector

        MSG = "RAAF prompts must use 'def system' and 'def user' methods, " \
              "not custom method names like '%<method>s' (DEC-019)."

        MSG_MISSING = "RAAF prompts must define 'system' and/or 'user' methods (DEC-019)."

        REQUIRED_METHODS = %i[system user].freeze
        FORBIDDEN_METHODS = %i[prompt render template content message].freeze

        def on_class(node)
          return unless raaf_prompt_class?(node)

          check_forbidden_methods(node)
          check_required_methods(node)
        end

        private

        def raaf_prompt_class?(node)
          # Exclude ApplicationPrompt - it's a base class
          class_name = node.identifier.source
          return false if class_name == "ApplicationPrompt"

          parent_class = node.parent_class
          return false unless parent_class

          parent_name = parent_class.source

          # Check if it inherits from RAAF prompt base
          raaf_prompt_base?(parent_name) || in_prompts_directory?
        end

        def raaf_prompt_base?(class_name)
          patterns = [
            "RAAF::DSL::Prompts::Base",
            "::RAAF::DSL::Prompts::Base",
            "Prompts::Base",
            "ApplicationPrompt"
          ]

          patterns.include?(class_name)
        end

        def in_prompts_directory?
          file_path = processed_source.file_path
          file_path.include?("app/ai/prompts/")
        end

        def check_forbidden_methods(class_node)
          each_method_def(class_node) do |method_node|
            method_name = method_node.method_name

            if FORBIDDEN_METHODS.include?(method_name)
              add_offense(
                method_node.loc.name,
                message: format(MSG, method: method_name)
              ) do |corrector|
                # Suggest renaming to 'system' as a default
                corrector.replace(method_node.loc.name, "system")
              end
            end
          end
        end

        def check_required_methods(class_node)
          defined_methods = []

          each_method_def(class_node) do |method_node|
            defined_methods << method_node.method_name
          end

          # Check if at least one required method is defined
          has_required = REQUIRED_METHODS.any? { |method| defined_methods.include?(method) }

          unless has_required
            add_offense(class_node.identifier, message: MSG_MISSING)
          end
        end

        def each_method_def(node, &block)
          return unless node

          if node.def_type?
            yield(node)
          elsif node.respond_to?(:children)
            node.children.each do |child|
              next unless child.is_a?(Parser::AST::Node)
              each_method_def(child, &block)
            end
          end
        end
      end
    end
  end
end
