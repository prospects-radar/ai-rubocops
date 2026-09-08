# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RAAF/EvaluatorLabelString` — evaluator labels must be the strings `"good"`,
  `"average"` and `"bad"`. `EvaluationResult` sorts results by comparing against
  string literals, so a symbol label lands in no bucket: `failed_fields` comes
  back empty while `passed?` returns false. Autocorrects.
- `RAAF/EvaluatorName` — an evaluator without `evaluator_name` cannot be
  registered, discovered, or named in a continuous-evaluation policy.
- `RAAF/EvaluatorBaseClass`, `RAAF/EvaluatorThresholdDefaults` — threshold
  resolution and result building belong in the shared base class.
- `RAAF/DiscardedPromptBuild`, `RAAF/MockImplementation` — an evaluator that
  builds a prompt and drops it, or scores with a `mock_*` heuristic, reads as an
  LLM judge without ever reaching a model.
- `RAAF/UnregisteredEvaluator` — keeps the require manifest and the registry
  array in step.
- `config/default.yml`, merged into RuboCop's default configuration on load.
  A `require:` is process-wide, so without this a cop's `Include` would apply
  only under the `.rubocop.yml` that declares it and the cop would run unscoped
  everywhere else. Only the new cops are listed; every other cop stays
  configured by the consuming project.

## [1.0.0] - 2026-03-25

### Added

- Initial extraction from ProspectsRadar main codebase into standalone gem
- **DesignSystem cops** (33 cops): Component API enforcement, design token validation,
  deprecation guards (Preline, Tailwind), atomic design hierarchy
- **ProspectsRadar cops** (27 cops): Service layer patterns, controller hygiene,
  tenant safety, RAAF agent conventions, I18n enforcement
- **RSpec cops** (7 cops): `build_stubbed` preference, tenant setup, `aggregate_failures`,
  flaky time patterns, shared context promotion
- **FactoryBot cops** (1 cop): Tenant association requirement for multi-tenant safety
- **Cucumber cops** (4 cops): Atomic step enforcement, consistent wait timeouts,
  silent database rescue prevention
- Comprehensive guide documentation for security-critical cops
- Spec suite with integration tests for DesignSystem cops
