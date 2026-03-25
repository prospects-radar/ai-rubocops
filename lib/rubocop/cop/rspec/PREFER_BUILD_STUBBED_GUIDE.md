# RSpec/PreferBuildStubbedForNonPersisted

## Overview

This cop suggests using `build_stubbed` instead of `create` when database persistence is not needed. This can result in **10-100x faster test suites** by avoiding unnecessary database operations.

**MASSIVE PERFORMANCE WIN** - Potentially 1000+ opportunities across the codebase.

## Performance Impact

### Speed Comparison

```ruby
# Slow (database hit)
Benchmark.ips do |x|
  x.report("create") { create(:user) }
  x.report("build_stubbed") { build_stubbed(:user) }
end

# Results:
# create:         10 i/s
# build_stubbed:  1000 i/s  (100x faster!)
```

### Real Test Suite Impact

```ruby
# Example spec with 100 tests
# BEFORE: Each test creates 5 records = 500 database inserts
# Time: 30 seconds

# AFTER: 80% use build_stubbed = 400 avoided database hits
# Time: 5 seconds (6x faster!)
```

## Examples

### ❌ Slow - Unnecessary `create`

```ruby
RSpec.describe UserFormatter do
  let(:user) { create(:user, name: "John", email: "john@example.com") }

  describe "#format_name" do
    it "returns formatted name" do
      # ⚠️ Database hit just to read attributes!
      expect(formatter.format_name(user)).to eq("John (john@example.com)")
    end
  end
end
```

**Problem:** Test only reads attributes - doesn't need database at all.

### ✅ Fast - Uses `build_stubbed`

```ruby
RSpec.describe UserFormatter do
  let(:user) { build_stubbed(:user, name: "John", email: "john@example.com") }

  describe "#format_name" do
    it "returns formatted name" do
      # ✅ No database hit - instant!
      expect(formatter.format_name(user)).to eq("John (john@example.com)")
    end
  end
end
```

**Result:** 10-100x faster, same test coverage.

## When to Use Each

### Use `build_stubbed` When:

- ✅ Test only reads attributes
- ✅ Test only checks associations (stubbed automatically)
- ✅ Object is passed to methods that don't persist
- ✅ Testing presenters, formatters, serializers
- ✅ Testing validations (can use `build` too)

### Use `create` When:

- ❌ Test calls `.save`, `.update`, `.destroy`
- ❌ Test calls `.reload`
- ❌ Test queries database for the record
- ❌ Test checks database state after operation
- ❌ Testing database constraints/triggers

### Use `build` When:

- ⚠️ Testing validations on unsaved records
- ⚠️ Need invalid record (build_stubbed can't be invalid)

## Common Patterns

### Pattern 1: Service That Doesn't Persist

```ruby
# ❌ SLOW
RSpec.describe CompanyFormatter do
  let(:company) { create(:company) }  # Database hit

  it "formats company info" do
    result = formatter.format(company)
    expect(result).to include(company.name)
  end
end

# ✅ FAST
RSpec.describe CompanyFormatter do
  let(:company) { build_stubbed(:company) }  # In-memory

  it "formats company info" do
    result = formatter.format(company)
    expect(result).to include(company.name)
  end
end
```

### Pattern 2: Presenter/Serializer

```ruby
# ❌ SLOW
RSpec.describe ProductPresenter do
  let(:product) { create(:product) }  # Database hit

  it "presents product data" do
    presented = described_class.new(product).as_json
    expect(presented[:name]).to eq(product.name)
  end
end

# ✅ FAST
RSpec.describe ProductPresenter do
  let(:product) { build_stubbed(:product) }  # In-memory

  it "presents product data" do
    presented = described_class.new(product).as_json
    expect(presented[:name]).to eq(product.name)
  end
end
```

### Pattern 3: Associations (Stubbed Automatically)

```ruby
# ❌ SLOW - Creates product AND company
let(:product) { create(:product) }

it "returns company name" do
  # Creates company in database too!
  expect(product.company.name).to eq("Acme")
end

# ✅ FAST - Stubs both
let(:product) { build_stubbed(:product) }

it "returns company name" do
  # Stubbed company - no database!
  expect(product.company.name).to eq("Acme")
end
```

### Pattern 4: When You MUST Use create

```ruby
# ✅ CORRECT - Service persists the record
RSpec.describe CompanyService do
  let(:company) { create(:company) }  # Need real record

  describe "#archive" do
    it "marks company as archived" do
      service.archive(company.id)
      expect(company.reload.archived?).to be true  # Needs database
    end
  end
end

# ❌ WRONG - build_stubbed won't work here
let(:company) { build_stubbed(:company) }  # Can't reload stubbed record!
```

## Detection Logic

This cop suggests `build_stubbed` when it finds:

1. **`let` block** with `create(:symbol)`
2. **No persistence methods** called on variable:
   - `save`, `update`, `destroy`, `reload`
   - `increment`, `decrement`, `toggle`, `touch`
   - etc.

**Does NOT autocorrect** - you must review each case manually.

## Migration Strategy

### Step 1: Run the Cop

```bash
bin/rubocop --only RSpec/PreferBuildStubbedForNonPersisted spec/
```

### Step 2: Review Each Violation

For each flagged `create`:

- Does the test call database methods? → Keep `create`
- Does it only read attributes? → Change to `build_stubbed`

### Step 3: Test One File at a Time

```bash
# Change one spec file
# spec/presenters/company_presenter_spec.rb

# Run just that spec
bin/rspec spec/presenters/company_presenter_spec.rb

# If green, commit and move to next file
```

### Step 4: Measure Impact

```bash
# Before
time bin/rspec spec/presenters/

# After
time bin/rspec spec/presenters/

# Calculate speedup
```

## Gotchas and Edge Cases

### Gotcha 1: Uniqueness Validations

```ruby
# ❌ May fail with build_stubbed
let(:user1) { build_stubbed(:user, email: "test@example.com") }
let(:user2) { build_stubbed(:user, email: "test@example.com") }

it "enforces unique email" do
  user1.save
  user2.valid?  # Uniqueness check needs database
  expect(user2.errors[:email]).to be_present
end

# ✅ Use create for uniqueness tests
let(:user1) { create(:user, email: "test@example.com") }
let(:user2) { build(:user, email: "test@example.com") }
```

### Gotcha 2: Callbacks That Set Attributes

```ruby
# Model with callback
class Company < ApplicationRecord
  before_create :generate_api_key
end

# ❌ Stubbed record won't have api_key
let(:company) { build_stubbed(:company) }
expect(company.api_key).to be_present  # Fails - callback didn't run

# ✅ Use create if callback matters
let(:company) { create(:company) }
expect(company.api_key).to be_present  # Works
```

### Gotcha 3: Database-Level Defaults

```ruby
# Migration sets default
t.boolean :active, default: true

# ❌ Stubbed record might not have default
let(:user) { build_stubbed(:user) }
expect(user.active).to be true  # May fail if factory doesn't set it

# ✅ Either use create or update factory
factory :user do
  active { true }  # Explicitly set in factory
end
```

## Measuring Performance Gains

### Add RSpec Profiling

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.profile_examples = 10  # Show 10 slowest examples
end
```

### Run with Timing

```bash
bin/rspec --profile 50 spec/ > profile_before.txt

# Make changes to use build_stubbed

bin/rspec --profile 50 spec/ > profile_after.txt

# Compare
```

### Expected Results

- **Small speedup:** 10-20% faster (few changes)
- **Medium speedup:** 2-3x faster (many changes)
- **Large speedup:** 5-10x faster (aggressive optimization)

## Configuration

```yaml
# .rubocop.yml
RSpec/PreferBuildStubbedForNonPersisted:
  Enabled: true
  Include:
    - "spec/**/*_spec.rb"
  Exclude:
    - "spec/models/**/*_spec.rb" # Models often need persistence
    - "spec/requests/**/*_spec.rb" # Request specs need persistence
```

## False Positives

This cop may flag cases where `create` is actually needed:

### Case 1: Implicit Database Queries

```ruby
# Cop flags this
let(:user) { create(:user) }

it "finds user by email" do
  # Actually queries database!
  found = User.find_by(email: user.email)
  expect(found).to eq(user)
end

# Solution: Keep create, maybe add comment
let(:user) { create(:user) }  # rubocop:disable RSpec/PreferBuildStubbedForNonPersisted
```

### Case 2: Tenant Scoping

```ruby
# Cop flags this
let(:company) { create(:company) }

it "scopes to current tenant" do
  ActsAsTenant.with_tenant(company.account) do
    # Queries with tenant scope
    expect(Company.all).to include(company)
  end
end

# Solution: Keep create
```

## Impact Assessment

Based on codebase analysis:

- **Potential candidates:** 1000+ (estimated)
- **Conservative conversion rate:** 50-70%
- **Expected speedup:** 2-5x for affected specs
- **Overall suite speedup:** 30-50% (estimated)
- **Severity:** HIGH (performance, developer experience)
- **Fix complexity:** Medium (manual review required)
- **Autocorrect:** No (requires human judgment)

---

_Part of ProspectsRadar custom RuboCop cops - enforcing architecture at commit time_
