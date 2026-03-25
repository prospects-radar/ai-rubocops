# Cucumber/PreferAtomicSteps

## What it does

Detects hard-coded Capybara interactions in organism and molecule step definitions. These higher-level step files should compose atomic/molecule steps using `step '...'` instead of directly calling Capybara methods.

## Why is this bad?

ProspectsRadar follows an **atomic design pattern** for Cucumber step definitions:

- **Atoms** (`atoms/`): Primitive Capybara interactions (clicks, fills, assertions)
- **Molecules** (`molecules/`): Simple composed steps combining 2-3 atoms
- **Organisms** (`organisms/`): Complex workflows composing atoms and molecules
- **Universal** (`universal/`): Cross-cutting reusable steps

When organism or molecule steps contain hard-coded Capybara calls (`find()`, `click_button`, `fill_in`, etc.), it:

1. **Violates the abstraction layer** - organisms/molecules should be at a higher level
2. **Reduces reusability** - the interaction logic is hidden and can't be reused
3. **Harms maintainability** - changes to UI selectors require editing multiple files
4. **Breaks testability** - harder to test complex workflows when low-level details are mixed in

## Examples

### ❌ Bad (Organism with hard-coded Capybara)

```ruby
# features/step_definitions/organisms/authentication.rb
When('I log out') do
  find('[data-testid="sidebar-user-toggle"]').click  # BAD
  find('[data-testid="user-menu-sign-out"]').click   # BAD
end
```

### ✅ Good (Organism composing atomic steps)

```ruby
# features/step_definitions/organisms/authentication.rb
When('I log out') do
  step 'I click "sidebar-user-toggle"'  # Delegates to atom
  step 'I click "user-menu-sign-out"'   # Delegates to atom
end
```

### ❌ Bad (Molecule with direct field access)

```ruby
# features/step_definitions/molecules/form_fields.rb
When('I enter company name {string}') do |name|
  fill_in 'customer_company[name]', with: name  # BAD
end
```

### ✅ Good (Molecule composing atomic step)

```ruby
# features/step_definitions/molecules/form_fields.rb
When('I enter company name {string}') do |name|
  step "I fill in \"customer_company[name]\" with \"#{name}\""  # GOOD
end
```

### ✅ Allowed (Atom with direct Capybara)

```ruby
# features/step_definitions/atoms/clicks.rb
When('I click {string}') do |element_identifier|
  find_element_smart(element_identifier).click  # OK in atoms
end
```

### ✅ Allowed (Universal with Capybara)

```ruby
# features/step_definitions/universal/field_steps.rb
When('I fill in {string} with {string}') do |field, value|
  field = find_field_element(field)  # OK in universal
  field.set(value)
end
```

## Configuration

```yaml
# .rubocop.yml
Cucumber/PreferAtomicSteps:
  Description: "Enforces step composition in organisms/molecules instead of hard-coded Capybara."
  Enabled: true
  Include:
    - "features/step_definitions/organisms/**/*.rb"
    - "features/step_definitions/molecules/**/*.rb"
  Exclude:
    - "features/step_definitions/atoms/**/*.rb" # Atoms can use Capybara
    - "features/step_definitions/universal/**/*.rb" # Universal can use Capybara
```

## Detected Methods

The cop detects these Capybara interaction methods:

- **Clicks**: `click`, `click_button`, `click_link`, `click_on`
- **Forms**: `fill_in`, `select`, `choose`, `check`, `uncheck`
- **Files**: `attach_file`
- **Finders**: `find`, `find_field`, `find_button`, `find_link`
- **Scoping**: `within`
- **Dialogs**: `accept_alert`, `dismiss_confirm`, `accept_confirm`
- **JavaScript**: `execute_script`, `evaluate_script`
- **Keyboard**: `send_keys`

## Allowed Patterns

The cop allows:

- **Step delegation**: `step 'I click "button"'` (the GOOD pattern!)
- **Custom helpers**: Methods matching patterns like `fill_in_or_select_`, `_test_id`, `sign_in_`
- **Query methods**: `has_css?`, `has_content?`, etc. (non-interactive)
- **Expectations**: `expect(page).to have_css(...)`
- **Test data**: `create(:user)`, `with_tenant { ... }`
- **Navigation**: `visit dashboard_path` (atomic enough)

## Refactoring Guide

When the cop flags a violation:

1. **Check if an atomic step exists** - Use existing atoms like `I click "..."` or `I fill in "..." with "..."`
2. **Create a new atom if needed** - Add to `features/step_definitions/atoms/` if it's a new primitive
3. **Use step delegation** - Replace `find(...).click` with `step 'I click "element-id"'`
4. **Keep high-level logic** - Organisms/molecules should describe WHAT, not HOW

### Before

```ruby
When('I complete the signup flow') do
  fill_in 'user[email]', with: 'test@example.com'
  fill_in 'user[password]', with: 'password123'
  find('[data-testid="submit-button"]').click
  expect(page).to have_content('Welcome')
end
```

### After

```ruby
When('I complete the signup flow') do
  step 'I fill in "user[email]" with "test@example.com"'
  step 'I fill in "user[password]" with "password123"'
  step 'I click "submit-button"'
  step 'I should see "Welcome"'
end
```

## Related Cops

- `Cucumber/PreferTestId` - Enforces data-test-id usage
- `Cucumber/PreferHaveOverHasCss` - Enforces expect() over conditionals
- `ProspectsRadar/NoSleepInCucumber` - Prevents sleep() in tests

## Further Reading

- [Atomic Design Methodology](https://bradfrost.com/blog/post/atomic-web-design/)
- [Cucumber Step Organization Best Practices](https://cucumber.io/docs/gherkin/step-organization/)
- Project docs: `features/step_definitions/README.md`
