# frozen_string_literal: true

module RuboCop
  module Cop
    module Mcp
      # MCP tools call the application's own services, the ones the screens use,
      # and extend those when an action or a permitted field is missing. An
      # MCP-only service layer (`Mcp::*Service`) drifts from them: a wrapper can
      # report a field as saved that the app service never permits.
      #
      # Flags:
      # - any class defined under app/services/mcp/ (a new wrapper), and
      # - any reference to an `Mcp::...Service` constant from an MCP tool.
      #
      # Existing wrappers and the tools that still use them are listed in the
      # app's Exclude for this cop; the list only shrinks.
      #
      # @example Bad — a new MCP-only service
      #   # app/services/mcp/product_service.rb
      #   module Mcp
      #     class ProductService < Base
      #     end
      #   end
      #
      # @example Bad — a tool going through one
      #   # app/ai/tools/mcp/member/update_product.rb
      #   ::Mcp::ProductService.new(user: context.user, account: context.account).update(...)
      #
      # @example Good — the tool calls the app service, extended where needed
      #   # app/ai/tools/mcp/member/update_product.rb
      #   call_service(::ProductService, :update, id: product.id, data: changes)
      #
      class NoServiceWrappers < Base
        SERVICE_MSG = "Do not add MCP-specific services. Call the app service the screens use " \
                      "(ProductService, CompanyService, ...) from the tool, and extend that service " \
                      "when it lacks an action or a permitted field."

        TOOL_MSG = "MCP tools call app services directly (`call_service(::ProductService, :update, ...)`), " \
                   "not an `Mcp::*Service` wrapper."

        WRAPPER = /\A(?:::)?Mcp::\w+Service\z/

        def on_class(node)
          return unless mcp_service_file?
          return if base_file?

          add_offense(node.identifier, message: SERVICE_MSG)
        end

        def on_const(node)
          return unless mcp_tool_file?
          return unless node.source.match?(WRAPPER)
          return if node.parent&.const_type? # report the outermost constant once

          add_offense(node, message: TOOL_MSG)
        end

        private

        def mcp_service_file?
          processed_source.path.to_s.include?("app/services/mcp/")
        end

        def mcp_tool_file?
          processed_source.path.to_s.include?("app/ai/tools/mcp/")
        end

        def base_file?
          processed_source.path.to_s.end_with?("/base.rb")
        end
      end
    end
  end
end
