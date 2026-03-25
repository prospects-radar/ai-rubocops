# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Detects user-provided data interpolated directly into AI prompt strings.
      #
      # Prompt injection is a real risk when user input flows into system or user
      # prompts without sanitization. This cop flags string interpolation in prompt
      # methods that reference parameters, instance variables, or method calls that
      # likely contain user data.
      #
      # @example
      #   # bad - direct interpolation of user data in system prompt
      #   def system
      #     "You are analyzing #{@company.name}. #{@company.description}"
      #   end
      #
      #   # good - user data in user prompt with clear separation
      #   def system
      #     "You are a company analyst. Respond in JSON format."
      #   end
      #
      #   def user
      #     "Analyze this company: #{@company.name}"
      #   end
      #
      #   # good - using sanitize helper
      #   def system
      #     "You are analyzing #{sanitize_prompt_input(@company.name)}"
      #   end
      #
      class PromptUserInputEscaping < Base
        MSG = "Avoid interpolating user data directly in system prompts. " \
              "Place user-controlled data in the `user` prompt method instead, " \
              "or use a sanitization helper."

        def on_def(node)
          return unless in_prompt_file?
          return unless node.method_name == :system

          check_interpolations(node)
        end

        private

        def in_prompt_file?
          file_path = processed_source.file_path
          file_path.include?("app/ai/prompts/")
        end

        def check_interpolations(node)
          each_dstr_node(node) do |dstr|
            dstr.children.each do |child|
              next unless child.begin_type? # interpolation #{...}

              expr = child.children.first
              next unless expr

              if unsafe_interpolation?(expr)
                add_offense(child, message: MSG)
              end
            end
          end
        end

        def each_dstr_node(node, &block)
          return unless node.is_a?(Parser::AST::Node)

          yield(node) if node.dstr_type?

          node.children.each do |child|
            each_dstr_node(child, &block)
          end
        end

        def unsafe_interpolation?(expr)
          # Instance variables that likely contain user data
          return true if user_data_ivar?(expr)

          # Method calls on user-data objects
          return true if user_data_method_chain?(expr)

          # Direct parameter/argument references
          return true if parameter_reference?(expr)

          false
        end

        def user_data_ivar?(expr)
          return false unless expr.ivar_type?

          var_name = expr.children[0].to_s
          # Common patterns for user-controlled data
          user_data_patterns = %w[
            @company @prospect @product @stakeholder @contact
            @input @query @search @params @request @body
            @name @description @title @content @text @message
          ]

          user_data_patterns.any? { |pattern| var_name.start_with?(pattern) }
        end

        def user_data_method_chain?(expr)
          return false unless expr.send_type?

          receiver = expr.receiver
          return false unless receiver

          # Check for chains like @company.name, @prospect.description
          if receiver.ivar_type?
            return user_data_ivar?(receiver)
          end

          # Check for chains like company.name, prospect.title
          if receiver.lvar_type? || receiver.send_type?
            method_name = expr.method_name.to_s
            data_methods = %w[
              name description title content text body
              summary notes comment query search_term
              bio headline tagline url website
            ]

            return data_methods.include?(method_name)
          end

          false
        end

        def parameter_reference?(expr)
          return false unless expr.lvar_type?

          var_name = expr.children[0].to_s
          %w[input query search params request body content text].include?(var_name)
        end
      end
    end
  end
end
