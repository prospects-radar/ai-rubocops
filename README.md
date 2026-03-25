# ai-rubocops

Custom RuboCop cops for the ProspectsRadar application. Enforces architectural conventions across the design system, service layer, RAAF AI agents, testing, and multi-tenant safety.

## Installation

Add to your `Gemfile`:

```ruby
gem "ai-rubocops", path: "vendor/local_gems/ai-rubocops"
```

Then in `.rubocop.yml`:

```yaml
require:
  - ai-rubocops
```

## Cop Categories

### DesignSystem (33 cops)

Enforce GlassMorph atomic design system conventions.

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `StandardApi` | Base class, view_template, namespace conventions | Yes |
| `ComponentHierarchy` | Molecules use only Atoms, not other Molecules/Organisms | No |
| `NoRenderInAtoms` | Atoms must not render other components | No |
| `NoRawHtmlInOrganisms` | Use components instead of raw HTML in organisms | No |
| `NoRawHtmlInViews` | Use components instead of raw HTML in views | No |
| `BadgeValidColor` | Badge color values from approved set | No |
| `UseRealBadgeComponent` | Use Badge atom instead of raw `<span class="badge">` | No |
| `NoClassOnBadge` | Don't add custom classes to Badge component | No |
| `UseRealHeadingComponent` | Use Heading atom instead of raw `<h1>`-`<h6>` | No |
| `UseRealSeparatorComponent` | Use Separator atom instead of raw `<hr>` | No |
| `UseRealScoreBadgeComponent` | Use ScoreBadge component for scores | No |
| `ClassParameter` | Parameter naming conventions for `class:` | No |
| `DataParameter` | Parameter naming conventions for `data:` | No |
| `NoHardcodedHtmlComponents` | Use GlassMorph components instead of Bootstrap HTML | No |
| `NoComponentDatabaseQueries` | Components must not query the database | No |
| `ComponentTidUsage` | Use `tid()` helper for test IDs | Yes |
| `ComponentTestIdRequired` | Components must have test IDs | No |
| `NoInlineEventHandlers` | Use Stimulus controllers instead | No |
| `NoInlineStyles` | Use CSS classes instead of inline styles | No |
| `EnforceDesignTokenClasses` | Use design tokens, not hardcoded colors | No |
| `ButtonVariantRequired` | Button must specify variant | No |
| `SinglePrimaryButtonPerSection` | Max one primary button per section | No |
| `NoRawButtonsInViews` | Use Button atom in views | No |
| `NoRawLinkTags` | Use Link atom instead of raw `<a>` | No |
| `ModalUsage` | Modal component conventions | No |
| `WizardStructure` | Wizard step structure | No |
| `NoNewPrelineUsage` | Deprecation: no new Preline CSS | No |
| `NoNewTailwindUsage` | Deprecation: no new Tailwind CSS | No |
| `NoRawBiIconClasses` | Use Icon atom instead of `bi bi-*` classes | No |
| `NoRawSvgInComponents` | Use Icon atom instead of inline SVGs | No |
| `NoPrelineInGlassMorph` | No Preline in GlassMorph components | No |
| `LookbookOnlyGlassMorph` | Lookbook previews only for GlassMorph | No |
| `InteractiveAriaRequired` | Icon-only buttons need `aria_label:` | No |

### Architecture (9 cops)

Enforce application architecture: services, controllers, and conventions.

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `ServiceInheritance` | Services must inherit from `BaseService` | Yes |
| `NoCurrentUserParameter` | Use `Current.current_user` instead | No |
| `ServiceActionDispatch` | No `case action` in services | No |
| `ServiceResponseFormat` | Return `success_result`/`error_result` | No |
| `ServiceRescueFrom` | Use `rescue_from` DSL or return `error_result` | No |
| `ControllerServiceResultCheck` | Check `.success?` before redirect | No |
| `ControllerBusinessLogic` | Controllers delegate to services | No |
| `NoControllerAuthorization` | Authorization in services, not controllers | No |
| `I18nNoDefault` | No `default:` parameter in `I18n.t` | Yes |

### RAAF (11 cops)

Enforce RAAF AI agent conventions and safety.

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `AgentRun` | Agents use `.run`, not `.call` | Yes |
| `PromptMethods` | Prompts define `system` and `user` methods | No |
| `AgentInheritance` | Agents inherit from `ApplicationAgent` | Yes |
| `AgentToolScope` | Agent tool scope enforcement | No |
| `AgentNoInlineOrchestration` | No inline orchestration in agents | No |
| `SchemaNestedArrayRequired` | Nested arrays in schemas need `required: true` | Yes |
| `PromptLanguageInstructions` | Prompt language conventions | No |
| `Logger` | Use RAAF logger in agents | No |
| `PromptUserInputEscaping` | Don't interpolate user data in system prompts | No |
| `AgentSchemaValidation` | Validate output against declared schema | No |
| `AgentContextImmutability` | Don't mutate shared agent context | No |

### MultiTenancy (1 cop)

Enforce multi-tenant safety.

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `TenantScopeRequired` | Models with `belongs_to :account` need `acts_as_tenant` | No |

### Convention (2 cops)

General code conventions.

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `PreferSymbolJsonAccess` | Use symbol keys for JSON access | No |
| `FrozenStringLiteral` | Frozen string literal pragma (disabled) | Yes |

### RSpec (7 cops)

Improve test quality and reliability.

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `PreferBuildStubbedForNonPersisted` | Use `build_stubbed` over `create` when possible | No |
| `ServiceRequiresTenantSetup` | Service specs must set up tenant context | No |
| `PreferLetOverInstanceVariable` | Use `let` blocks instead of `@instance_vars` | No |
| `PreferSharedContext` | DRY up repeated test setup | No |
| `FlakyTimePatterns` | Detect `Time.now`/`Date.today` without time freezing | No |
| `TestDataOrdering` | Avoid `.first`/`.last` without explicit ordering | No |
| `AggregateFailures` | Use `:aggregate_failures` for 3+ expectations | No |

### FactoryBot (1 cop)

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `ExplicitTenantHandling` | Factories must include `association :account` for tenant safety | No |

### Cucumber (6 cops)

| Cop | Purpose | Auto-fix |
|-----|---------|----------|
| `ConsistentWaitTimeout` | Consistent wait timeout values | No |
| `PreferHaveOverHasCss` | Use `expect().to have_css()` over conditionals | No |
| `PreferAtomicSteps` | Use atomic step composition in organisms/molecules | No |
| `NoSilentDatabaseRescue` | Don't silently rescue database errors | No |
| `PreferTestId` | Use `data-testid` in step definitions | No |
| `NoSleepInCucumber` | No `sleep()` in Cucumber steps | No |

## Guide Documents

Several cops include detailed guide documents explaining the rationale and migration strategies:

- **[Model Multi-Tenancy Guide](lib/rubocop/cop/multi_tenancy/MODEL_MULTI_TENANCY_GUIDE.md)** - Security-critical tenant isolation
- **[No Sleep Guide](lib/rubocop/cop/cucumber/NO_SLEEP_GUIDE.md)** - Replacing sleep with Capybara waits
- **[Schema Nested Array Required Guide](lib/rubocop/cop/raaf/SCHEMA_NESTED_ARRAY_REQUIRED_GUIDE.md)** - RAAF schema validation
- **[Prefer Build Stubbed Guide](lib/rubocop/cop/rspec/PREFER_BUILD_STUBBED_GUIDE.md)** - 10-100x faster tests
- **[Require Tenant Association Guide](lib/rubocop/cop/factory_bot/REQUIRE_TENANT_ASSOCIATION_GUIDE.md)** - Multi-tenant factory safety
- **[Prefer Atomic Steps Guide](lib/rubocop/cop/cucumber/PREFER_ATOMIC_STEPS.md)** - Atomic design for Cucumber

## Usage

```bash
# Run all custom cops
bundle exec rubocop

# Run a specific category
bundle exec rubocop --only DesignSystem
bundle exec rubocop --only Architecture
bundle exec rubocop --only RAAF
bundle exec rubocop --only MultiTenancy
bundle exec rubocop --only RSpec

# Run a specific cop
bundle exec rubocop --only Architecture/ServiceInheritance

# Auto-fix where possible
bundle exec rubocop -a --only Architecture/I18nNoDefault
```

## Development

After checking out the repo, run:

```bash
cd vendor/local_gems/ai-rubocops
bundle install
bundle exec rake spec
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run tests for a specific cop
bundle exec rspec spec/rubocop/cop/multi_tenancy/tenant_scope_required_spec.rb

# Run tests for a category
bundle exec rspec spec/rubocop/cop/design_system/
```

### Writing a New Cop

1. Create the cop file in `lib/rubocop/cop/<category>/<cop_name>.rb`
2. Add `require_relative` in `lib/ai-rubocops.rb`
3. Create a spec in `spec/rubocop/cop/<category>/<cop_name>_spec.rb`
4. Configure in the host project's `.rubocop.yml`

Cops extend `RuboCop::Cop::Base` and optionally include `AutoCorrector`:

```ruby
# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      class MyCop < Base
        extend AutoCorrector

        MSG = "Description of what this cop enforces."

        def on_class(node)
          # inspection logic
          add_offense(node, message: MSG) do |corrector|
            # autocorrect logic
          end
        end
      end
    end
  end
end
```

## License

MIT License. See [LICENSE](LICENSE) for details.
