# ComponentTidUsage RuboCop Cop

## Overview

The `DesignSystem/ComponentTidUsage` cop enforces the use of the `tid` helper for test IDs in components and views instead of hardcoded `data-testid` attributes.

## What it detects

The cop detects the following patterns:

### Direct data attributes (autocorrectable)

```ruby
# Bad
div(data: { testid: "submit-button" })
div(data: { test_id: "submit-button" })
button(data_testid: "cancel-btn")
button("data-testid" => "cancel-btn")
button(:"data-testid" => "cancel-btn")

# Good
div(**tid("submit-button"))
button(**tid("cancel-btn"))
```

### root_attributes with test_id (autocorrectable)

```ruby
# Bad
div(**root_attributes(base_class: "my-class", test_id: "my-element"))

# Good
div(**root_attributes(base_class: "my-class"), **tid("my-element"))
```

### Nested in form options (not autocorrectable)

```ruby
# Bad
form_with(
  model: @product,
  html: {
    data: {
      testid: "test-form"
    }
  }
)

# Good
form_with(
  model: @product,
  html: {
    **tid("test-form")
  }
)
```

## Configuration

The cop is enabled in `.rubocop.yml`:

```yaml
DesignSystem/ComponentTidUsage:
  Description: "Enforces use of tid helper for test IDs in components and views."
  Enabled: true
  Include:
    - "app/components/**/*.rb"
    - "app/views/**/*.rb"
```

## Running the cop

```bash
# Check all files
bundle exec rubocop --only DesignSystem/ComponentTidUsage

# Auto-correct where possible
bundle exec rubocop --only DesignSystem/ComponentTidUsage -a

# Check specific file
bundle exec rubocop app/components/my_component.rb --only DesignSystem/ComponentTidUsage
```

## Implementation details

The cop:

1. Checks files in `app/components/` and `app/views/`
2. Looks for Phlex element methods and Rails helpers (form_with, link_to, etc.)
3. Also checks GlassMorph component calls (methods starting with capital letters)
4. Detects various patterns of test ID usage
5. Provides autocorrection for most cases
6. Flags nested cases that need manual intervention
