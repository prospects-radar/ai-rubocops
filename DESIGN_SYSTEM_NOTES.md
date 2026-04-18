# Design System RuboCop Cops — Implementation Notes

## NoExtraClassesOnStandardizedComponents

**Current Behavior:**
- Atoms & molecules: ✅ Allowed to have extra Bootstrap utility classes
- Domain components: ❌ Restricted from having extra utilities

**Rationale:**
Atoms and molecules are foundational building blocks that compose into larger structures. They can use Bootstrap utilities internally for their implementation. Domain components (search, message strategy, etc.) should use composition (wrapping with Box/FlexColumn) or create CSS classes for their styling patterns.

**Examples:**

### Atoms (✅ Allowed)
```ruby
# atoms/info_row.rb
# Can use inline utilities for internal layout
Heading(level: 4, class: "fw-bold text-primary") { "Title" }

# molecules/page_header.rb
# Can use flex utilities as part of molecule composition
div(class: "d-flex align-items-center justify-between") do
  # content
end
```

### Domain Components (❌ Restricted)
```ruby
# search/search_results_list.rb
# WRONG:
Box(id: "search-results", class: "space-y-6") do
  # Should use CSS class instead
end

# RIGHT:
Box(id: "search-results", class: "search-results-lg-gap") do
  # CSS class defined in app/assets/stylesheets/glass_morph/components/search.css
end
```

## When to Create CSS Classes vs Disable Comments

**Create a CSS class when:**
- The pattern appears 2+ times in the same file
- The pattern could be reused across multiple components
- The styling is semantic (e.g., `.search-result-item` instead of raw utilities)

**Add disable comment when:**
- It's a true one-off situation
- The utility is applied to an atom/molecule for a specific context (rare)
- No reusable pattern exists

## File Path Based Rules

The cop checks file paths to determine component type:
- Contains `/glass_morph/atoms/` → Not restricted
- Contains `/glass_morph/molecules/` → Not restricted
- Everything else → Restricted
