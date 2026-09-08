# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # An evaluator must appear in every manifest that publishes it.
      #
      # Three lists are maintained by hand and must agree: the `require_relative`
      # block in `evaluators/all_evaluators.rb`, the `built_in_evaluators` array
      # in `dsl/evaluator_registry.rb`, and the class's own `evaluator_name`.
      # They already disagree — `Performance::CostEfficiency`,
      # `LLM::TaskCompletion` and `LLM::ToolCorrectness` are roughly 730 lines
      # that no caller can reach, because nothing requires or registers them.
      #
      # This cop reads the manifests named in `Manifests` and reports any
      # evaluator missing from one of them. The real fix is to make the registry
      # walk the namespace instead of restating it; until then, this keeps the
      # copies in sync.
      #
      # @example
      #   # bad — evaluators/performance/cost_efficiency.rb exists, but
      #   # all_evaluators.rb has no `require_relative "performance/cost_efficiency"`
      #   class CostEfficiency
      #     evaluator_name :cost_efficiency
      #   end
      class UnregisteredEvaluator < Base
        MSG = "`%<name>s` is missing from %<manifest>s, so nothing can load or resolve it."

        # @!method declares_evaluator_name?(node)
        def_node_search :declares_evaluator_name?, <<~PATTERN
          (send nil? :evaluator_name ...)
        PATTERN

        def on_class(node)
          return unless declares_evaluator_name?(node)
          return if allowed?(node)

          missing = missing_manifests(node)
          return if missing.empty?

          add_offense(
            node.identifier,
            message: format(MSG, name: node.identifier.source, manifest: missing.join(" and "))
          )
        end

        private

        # A manifest lists an evaluator either by its require path (relative to
        # the evaluators root, extension dropped) or by its class name.
        def missing_manifests(node)
          path = require_path
          name = node.identifier.short_name.to_s

          manifests.reject do |_name, source|
            source.include?(%("#{path}")) || source.match?(/\b#{Regexp.escape(name)}\b/)
          end.keys
        end

        def require_path
          absolute = processed_source.file_path.to_s
          root = "#{evaluators_root}/"
          index = absolute.index(root)
          return File.basename(absolute, ".rb") unless index

          absolute[(index + root.length)..].sub(/\.rb\z/, "")
        end

        def manifests
          @manifests ||= {}
          @manifests[File.dirname(processed_source.file_path.to_s)] ||=
            Array(cop_config.fetch("Manifests", [])).to_h do |relative|
              [File.basename(relative), read_manifest(relative)]
            end
        end

        # Manifests are declared relative to the repo root. Resolve them by
        # walking up from the file being inspected: that relationship holds
        # whatever the working directory is and whichever .rubocop.yml governs,
        # where `config.loaded_path` is empty for an implicit config.
        def read_manifest(relative)
          path = ancestors.lazy.map { |dir| File.join(dir, relative) }.find { |candidate| File.exist?(candidate) }
          path ? File.read(path) : ""
        end

        def ancestors
          dir = File.dirname(File.expand_path(processed_source.file_path.to_s))
          found = []
          while dir != "/" && !dir.empty?
            found << dir
            dir = File.dirname(dir)
          end
          found
        end

        def evaluators_root
          cop_config.fetch("EvaluatorsRoot", "evaluators")
        end

        def allowed?(node)
          Array(cop_config.fetch("AllowedNames", [])).include?(node.identifier.short_name.to_s)
        end
      end
    end
  end
end
