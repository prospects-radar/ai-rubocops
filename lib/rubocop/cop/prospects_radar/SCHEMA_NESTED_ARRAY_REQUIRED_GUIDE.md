# ProspectsRadar/SchemaNestedArrayRequired

## Overview

This cop ensures nested array fields in RAAF JSON schemas include `required: true`. Without this, RAAF validation **silently fails**, causing runtime errors when AI agents return unexpected data structures.

**CRITICAL FOR RUNTIME STABILITY** - Missing `required: true` causes silent validation failures.

## Examples

### ❌ Bad - Missing required: true

```ruby
class CompanyProductsSchema
  def self.build
    {
      type: "object",
      properties: {
        companies: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              products: {
                type: "array",  # ❌ Nested array without required: true
                items: {
                  type: "object",
                  properties: {
                    name: { type: "string" }
                  }
                }
              }
            }
          }
        }
      }
    }
  end
end
```

**Problem:** RAAF validation fails silently when AI returns:

```json
{
  "companies": [
    {
      "name": "Acme Corp"
      // Missing "products" array - validation passes but shouldn't!
    }
  ]
}
```

### ✅ Good - Includes required: true

```ruby
class CompanyProductsSchema
  def self.build
    {
      type: "object",
      properties: {
        companies: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              products: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    name: { type: "string" }
                  }
                },
                required: true  # ✅ Explicitly required
              }
            }
          },
          required: true  # ✅ Top-level array also required
        }
      }
    }
  end
end
```

**Result:** RAAF validation properly enforces structure. Missing fields are caught immediately.

## Why This Matters

### Silent Failure Example

```ruby
# Schema WITHOUT required: true
class ProductsSchema
  def self.build
    {
      type: "object",
      properties: {
        products: {
          type: "array",
          items: { type: "object" }
          # Missing: required: true
        }
      }
    }
  end
end

# Agent returns incomplete data
result = agent.run(prompt: "Find products")
# => { }  # Missing "products" key entirely

# Validation PASSES (should fail!)
validated_data = RAAF::Validator.validate(result, ProductsSchema.build)
# => No errors raised ⚠️

# Later in code:
validated_data[:products].each do |product|  # 💥 NoMethodError: undefined method `each' for nil
  process_product(product)
end
```

### With required: true

```ruby
# Schema WITH required: true
class ProductsSchema
  def self.build
    {
      type: "object",
      properties: {
        products: {
          type: "array",
          items: { type: "object" },
          required: true  # ✅ Enforced
        }
      }
    }
  end
end

# Agent returns incomplete data
result = agent.run(prompt: "Find products")
# => { }  # Missing "products" key

# Validation FAILS (correct behavior!)
validated_data = RAAF::Validator.validate(result, ProductsSchema.build)
# => RAAF::ValidationError: Missing required field 'products'

# Code never reaches unsafe iteration
```

## Autocorrect

This cop has **safe autocorrect** that adds `required: true` to array definitions:

```bash
# Review violations
bin/rubocop --only ProspectsRadar/SchemaNestedArrayRequired

# Auto-fix
bin/rubocop -a --only ProspectsRadar/SchemaNestedArrayRequired
```

Before autocorrect:

```ruby
products: {
  type: "array",
  items: { type: "string" }
}
```

After autocorrect:

```ruby
products: {
  type: "array",
  items: { type: "string" },
  required: true
}
```

## RAAF Schema Patterns

### Pattern 1: Simple Array

```ruby
# ❌ BAD
tags: {
  type: "array",
  items: { type: "string" }
}

# ✅ GOOD
tags: {
  type: "array",
  items: { type: "string" },
  required: true
}
```

### Pattern 2: Nested Arrays

```ruby
# ❌ BAD
companies: {
  type: "array",
  items: {
    type: "object",
    properties: {
      products: {
        type: "array",  # Missing required!
        items: { type: "object" }
      }
    }
  }
}

# ✅ GOOD
companies: {
  type: "array",
  items: {
    type: "object",
    properties: {
      products: {
        type: "array",
        items: { type: "object" },
        required: true  # ✅
      }
    }
  },
  required: true  # ✅ Both levels marked required
}
```

### Pattern 3: Optional vs Required Arrays

```ruby
# Array that MUST exist (even if empty)
products: {
  type: "array",
  items: { type: "object" },
  required: true  # Field must be present, [] is valid
}

# Array that CAN be omitted
# (Only use this if absence has semantic meaning!)
optional_tags: {
  type: "array",
  items: { type: "string" }
  # No required: true - can be nil/undefined
}
```

## Common Mistakes

### Mistake 1: Confusing "required" with "minItems"

```ruby
# ❌ WRONG - minItems doesn't replace required
products: {
  type: "array",
  items: { type: "object" },
  minItems: 1  # Means "if present, must have 1+ items"
  # Still missing: required: true
}

# ✅ CORRECT - Use both if array must be non-empty
products: {
  type: "array",
  items: { type: "object" },
  minItems: 1,
  required: true  # Field must be present AND non-empty
}
```

### Mistake 2: Top-Level Arrays Only

```ruby
# ❌ BAD - Only marked top level
companies: {
  type: "array",
  items: {
    type: "object",
    properties: {
      products: {
        type: "array",  # ❌ Forgot this one!
        items: { type: "object" }
      }
    }
  },
  required: true  # ✅ Top is marked
}

# ✅ GOOD - ALL nested arrays marked
companies: {
  type: "array",
  items: {
    type: "object",
    properties: {
      products: {
        type: "array",
        items: { type: "object" },
        required: true  # ✅ Nested marked too
      }
    }
  },
  required: true  # ✅ Top also marked
}
```

### Mistake 3: Forgetting After Refactoring

```ruby
# Original schema
products: { type: "array", items: { type: "string" }, required: true }

# After refactoring to nested objects - forgot required!
products: {
  type: "array",
  items: {
    type: "object",
    properties: {
      id: { type: "integer" },
      name: { type: "string" }
    }
  }
  # ❌ Lost required: true during refactor!
}
```

## Testing Schema Validation

```ruby
RSpec.describe "ProductsSchema" do
  let(:schema) { ProductsSchema.build }

  it "requires products array" do
    invalid_data = {}  # Missing products

    expect {
      RAAF::Validator.validate(invalid_data, schema)
    }.to raise_error(RAAF::ValidationError, /products/)
  end

  it "accepts empty array" do
    valid_data = { products: [] }

    expect {
      RAAF::Validator.validate(valid_data, schema)
    }.not_to raise_error
  end

  it "requires nested arrays in items" do
    invalid_data = {
      products: [
        { name: "Widget" }  # Missing features array
      ]
    }

    expect {
      RAAF::Validator.validate(invalid_data, schema)
    }.to raise_error(RAAF::ValidationError, /features/)
  end
end
```

## Detection Logic

This cop detects:

1. **File location:** `app/ai/` with `schemas/` or `_schema.rb` in path
2. **Hash structure:** Contains `type: "array"`
3. **Nested indicator:** Has `items:` key (not a simple array)
4. **Missing field:** No `required: true` pair in hash

Does NOT flag:

- Simple arrays without items (rare edge case)
- Arrays outside schema files
- Arrays that already have `required: true`

## Configuration

```yaml
# .rubocop.yml
ProspectsRadar/SchemaNestedArrayRequired:
  Enabled: true
  Include:
    - "app/ai/**/*_schema.rb"
    - "app/ai/**/schemas/**/*.rb"
```

## References

- **DEC-019:** RAAF schema validation requirements
- **DEC-020:** Agent prompt and schema patterns
- **Documentation:** `app/ai/CLAUDE.md` - Schema best practices
- **RAAF Docs:** Schema validation behavior

## Impact Assessment

Based on codebase analysis:

- **Schemas with nested arrays:** ~10-15 (estimated)
- **Missing required: true:** ~10-15 (estimated)
- **Severity:** CRITICAL (silent runtime failures)
- **Fix complexity:** Easy (autocorrect available)
- **Test impact:** May reveal existing bugs in validation

---

_Part of ProspectsRadar custom RuboCop cops - enforcing architecture at commit time_
