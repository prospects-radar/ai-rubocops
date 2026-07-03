# frozen_string_literal: true

module RuboCop
  module Cop
    module Mcp
      # Enforces that MCP components use the correct base class:
      #
      # - Mcp services (app/services/mcp/**/*.rb) must inherit from `Base`
      #   (resolving to `Mcp::Base` within the `module Mcp` context).
      # - MCP tools (app/ai/tools/mcp/**/*.rb) must inherit from
      #   `Ai::Tools::Mcp::Base`.
      #
      # @example Bad — service without base
      #   # app/services/mcp/company_service.rb
      #   module Mcp
      #     class CompanyService
      #     end
      #   end
      #
      # @example Bad — service inheriting wrong parent
      #   # app/services/mcp/company_service.rb
      #   module Mcp
      #     class CompanyService < BaseService
      #     end
      #   end
      #
      # @example Good — service inheriting Mcp::Base
      #   # app/services/mcp/company_service.rb
      #   module Mcp
      #     class CompanyService < Base
      #     end
      #   end
      #
      # @example Bad — tool without base
      #   # app/ai/tools/mcp/member/get_company.rb
      #   class GetCompany
      #   end
      #
      # @example Good — tool inheriting Ai::Tools::Mcp::Base
      #   # app/ai/tools/mcp/member/get_company.rb
      #   class GetCompany < Ai::Tools::Mcp::Base
      #   end
      #
      class AdapterBase < Base
        extend AutoCorrector

        SERVICE_MSG = "Mcp service classes must inherit from `Base` (`Mcp::Base`). " \
                      "Provides `call_service`, `fetch_one`, `fetch_many`, and " \
                      "`update_with_dry_run` without duplicating boilerplate."

        TOOL_MSG = "MCP tool classes must inherit from `Ai::Tools::Mcp::Base`. " \
                   "Provides `authorize_scope!`, `with_tenant`, `success`, `not_found`, " \
                   "and other tool DSL helpers."

        VALID_SERVICE_PARENTS = %w[Base Mcp::Base ::Mcp::Base].freeze
        VALID_TOOL_PARENTS    = %w[Ai::Tools::Mcp::Base].freeze
        # System-tier tools inherit the intermediate System::Base (itself an
        # Ai::Tools::Mcp::Base) which fixes the system scope/role. Accepted only
        # for files under app/ai/tools/mcp/system/, so a bare `Base` elsewhere is
        # still rejected.
        VALID_SYSTEM_TOOL_PARENTS = %w[Base System::Base Ai::Tools::Mcp::System::Base].freeze

        def on_class(node)
          if mcp_service_file? && !base_file?
            check_inheritance(node, VALID_SERVICE_PARENTS, SERVICE_MSG, "Base")
          elsif mcp_tool_file? && !base_file?
            valid = system_tool_file? ? VALID_TOOL_PARENTS + VALID_SYSTEM_TOOL_PARENTS : VALID_TOOL_PARENTS
            check_inheritance(node, valid, TOOL_MSG, "Ai::Tools::Mcp::Base")
          end
        end

        private

        def check_inheritance(node, valid_parents, msg, correct_parent)
          return if valid_parent?(node, valid_parents)

          add_offense(node.identifier, message: msg) do |corrector|
            if node.parent_class.nil?
              corrector.replace(node.loc.name, "#{node.identifier.source} < #{correct_parent}")
            else
              corrector.replace(node.parent_class, correct_parent)
            end
          end
        end

        def valid_parent?(node, valid_parents)
          parent = node.parent_class
          return false unless parent

          valid_parents.include?(parent.source)
        end

        def mcp_service_file?
          processed_source.path.to_s.include?("app/services/mcp/")
        end

        def mcp_tool_file?
          processed_source.path.to_s.include?("app/ai/tools/mcp/")
        end

        def system_tool_file?
          processed_source.path.to_s.include?("app/ai/tools/mcp/system/")
        end

        def base_file?
          processed_source.path.to_s.end_with?("/base.rb")
        end
      end
    end
  end
end
