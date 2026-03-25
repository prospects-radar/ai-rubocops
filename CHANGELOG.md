# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
