# frozen_string_literal: true

module RuboCop
  module Cop
    module DesignSystem
      # Prevents render calls inside GlassMorph atom components.
      #
      # Atoms are the smallest building blocks of the design system and must
      # contain only raw HTML. Any composition of other components belongs in
      # molecules or organisms (DEC-030).
      #
      # @example Bad — in app/components/glass_morph/atoms/my_atom.rb
      #   def view_template
      #     render Components::GlassMorph::Molecules::Card.new(...)
      #   end
      #
      # @example Good — in app/components/glass_morph/atoms/my_atom.rb
      #   def view_template
      #     div(class: "my-atom") { yield }
      #   end
      #
      # @example Allowed — Icon is a primitive visual atom, safe to render within other atoms
      #   def render_icon
      #     render Components::GlassMorph::Atoms::Icon.new(name: "star")
      #   end
      #
      class NoRenderInAtoms < Base
        MSG = "Atoms must contain only raw HTML — no `render` calls. " \
              "Move component composition to a molecule or organism."

        # Icon is a primitive visual atom (renders a single <i> tag) — safe to
        # render within other atoms as a leaf element.
        ALLOWED_ATOMS = %w[
          Components::GlassMorph::Atoms::Icon
        ].freeze

        def on_send(node)
          return unless in_atoms_scope?
          return unless node.method_name == :render
          return if node.receiver
          return if renders_allowed_atom?(node)

          add_offense(node, message: MSG)
        end

        private

        def renders_allowed_atom?(node)
          first_arg = node.first_argument
          return false unless first_arg&.send_type?

          # Match: Components::GlassMorph::Atoms::Icon.new(...)
          receiver = first_arg.receiver
          return false unless receiver

          ALLOWED_ATOMS.any? { |allowed| receiver.source == allowed }
        end

        def in_atoms_scope?
          processed_source.file_path.include?("app/components/glass_morph/atoms/")
        end
      end
    end
  end
end
