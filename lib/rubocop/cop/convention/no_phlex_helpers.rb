# frozen_string_literal: true

module RuboCop
  module Cop
    module Convention
      # Flags a receiverless `helpers` call in a Phlex view or component.
      #
      # phlex-rails deprecated `helpers` and prints a multi-line warning on
      # every render that reaches it, so one call floods the test and server
      # logs. Include the matching `Phlex::Rails::Helpers::*` module, register
      # the helper with `register_value_helper` / `register_output_helper`, or
      # reach the Rails view context explicitly with `view_context`.
      #
      # `helpers` on an explicit receiver (`ActionController::Base.helpers`)
      # and in controllers is a different method and is left alone; scope the
      # cop to Phlex directories with `Include`.
      #
      # @example
      #   # bad
      #   helpers.params[:tab]
      #   helpers.request.fullpath
      #
      #   # good
      #   view_context.params[:tab]
      #   include Phlex::Rails::Helpers::Request
      class NoPhlexHelpers < Base
        MSG = "phlex-rails deprecated `helpers`. Use `view_context`, a `Phlex::Rails::Helpers::*` " \
              "module, or `register_value_helper` instead."

        RESTRICT_ON_SEND = %i[helpers].freeze

        def on_send(node)
          return if node.receiver || node.arguments?

          add_offense(node)
        end
      end
    end
  end
end
