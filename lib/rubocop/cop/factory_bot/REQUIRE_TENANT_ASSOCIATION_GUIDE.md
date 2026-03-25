# FactoryBot/RequireTenantAssociation

## Overview

This cop ensures FactoryBot factories for tenant-scoped models include `association :account` to prevent test failures and ensure proper multi-tenancy in tests.

**CRITICAL FOR TEST RELIABILITY** - Missing account associations cause runtime errors when tests run with tenant context.

## Examples

### ❌ Bad - Missing account association

```ruby
FactoryBot.define do
  factory :company do
    name { "Acme Corp" }
    website { "https://acme.example.com" }
  end
end
```

**Problem:** When test creates a company, it won't have an account, causing:

1. `ActsAsTenant::Errors::NoTenantSet` if tenant context required
2. Database constraint violations if `account_id` is NOT NULL
3. Inconsistent test data that doesn't match production

### ✅ Good - Includes account association

```ruby
FactoryBot.define do
  factory :company do
    association :account
    name { "Acme Corp" }
    website { "https://acme.example.com" }
  end
end
```

**Result:** Every created company has a valid account, matching production behavior.

## Whitelisted Factories

The following factories are **intentionally cross-tenant** and do not need account association:

- `:account` - The tenant itself
- `:user` - Users can belong to multiple accounts via `account_users`
- `:account_user` - Join table connecting users to accounts

## Autocorrect

This cop has **safe autocorrect** that adds `association :account` as the first line in the factory:

```bash
# Review violations
bin/rubocop --only FactoryBot/RequireTenantAssociation

# Auto-fix
bin/rubocop -a --only FactoryBot/RequireTenantAssociation
```

## Why This Matters

### Runtime Error Example

```ruby
# WITHOUT account association in factory
RSpec.describe CompanyService do
  let(:company) { create(:company) }  # ❌ No account!

  before do
    ActsAsTenant.current_tenant = create(:account)
  end

  it "processes company" do
    service.call  # 💥 BOOM - company.account is nil
  end
end

# WITH account association in factory
RSpec.describe CompanyService do
  let(:company) { create(:company) }  # ✅ Has account!

  before do
    ActsAsTenant.current_tenant = company.account
  end

  it "processes company" do
    service.call  # ✅ Works perfectly
  end
end
```

### Database Constraint Violation

```ruby
# Migration has NOT NULL constraint
class CreateCompanies < ActiveRecord::Migration[7.0]
  def change
    create_table :companies do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
    end
  end
end

# WITHOUT account association
create(:company)  # 💥 PG::NotNullViolation: null value in column "account_id"

# WITH account association
create(:company)  # ✅ Creates account first, then company with account_id
```

## Best Practices

### Pattern 1: Shared Account for Performance

```ruby
# If multiple objects need same account
let(:account) { create(:account) }
let(:company1) { create(:company, account: account) }
let(:company2) { create(:company, account: account) }
let(:product) { create(:product, company: company1) }

# This creates 1 account instead of 3
```

### Pattern 2: Nested Associations

```ruby
FactoryBot.define do
  factory :product do
    association :company  # Company factory already has :account
    name { "Widget" }
  end
end

# Creates: Account → Company → Product (proper nesting)
```

### Pattern 3: Traits for Different Tenants

```ruby
FactoryBot.define do
  factory :company do
    association :account
    name { "Acme Corp" }

    trait :different_tenant do
      association :account, factory: :account
    end
  end
end

# Use case: Testing cross-tenant isolation
let(:company1) { create(:company) }
let(:company2) { create(:company, :different_tenant) }
```

## Common Mistakes

### Mistake 1: Explicit Account Creation

```ruby
# ❌ BAD - Manual account creation
FactoryBot.define do
  factory :company do
    account { Account.create!(name: "Test Account") }
  end
end

# ✅ GOOD - Association handles it
FactoryBot.define do
  factory :company do
    association :account
  end
end
```

### Mistake 2: Transient Attributes Instead

```ruby
# ❌ BAD - Overly complex
FactoryBot.define do
  factory :company do
    transient do
      account { nil }
    end

    after(:build) do |company, evaluator|
      company.account = evaluator.account || create(:account)
    end
  end
end

# ✅ GOOD - Simple association
FactoryBot.define do
  factory :company do
    association :account
  end
end
```

### Mistake 3: Wrong Association Name

```ruby
# ❌ BAD - Using foreign key instead of association name
FactoryBot.define do
  factory :company do
    account_id { create(:account).id }  # Creates orphaned account
  end
end

# ✅ GOOD - Using association name
FactoryBot.define do
  factory :company do
    association :account  # Proper ActiveRecord association
  end
end
```

## Testing Tenant Isolation with Factories

```ruby
RSpec.describe "Tenant isolation" do
  it "isolates data between different accounts" do
    company1 = create(:company)
    company2 = create(:company, :different_tenant)

    ActsAsTenant.with_tenant(company1.account) do
      expect(Company.all).to contain_exactly(company1)
    end

    ActsAsTenant.with_tenant(company2.account) do
      expect(Company.all).to contain_exactly(company2)
    end
  end
end
```

## Configuration

```yaml
# .rubocop.yml
FactoryBot/RequireTenantAssociation:
  Enabled: true
  Include:
    - "spec/factories/**/*.rb"
```

## Relationship to Other Cops

Works together with:

- **`ProspectsRadar/ModelMultiTenancy`** - Ensures models have `acts_as_tenant`
- **`RSpec/ServiceRequiresTenantSetup`** - Ensures specs set tenant context

## Impact Assessment

Based on codebase analysis:

- **Factories without account:** ~10-20 (estimated)
- **Severity:** HIGH (test failures)
- **Fix complexity:** Easy (autocorrect available)
- **Test impact:** None (should fix broken tests)

---

_Part of ProspectsRadar custom RuboCop cops - enforcing architecture at commit time_
