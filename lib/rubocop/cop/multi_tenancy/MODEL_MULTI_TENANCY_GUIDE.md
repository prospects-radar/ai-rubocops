# ProspectsRadar/ModelMultiTenancy

## Overview

This cop ensures all tenant-scoped models include `acts_as_tenant :account` to prevent data leakage between customer accounts.

**SECURITY CRITICAL** - Missing `acts_as_tenant` can cause data from one customer to leak into another customer's account.

## Examples

### ❌ Bad - Missing acts_as_tenant

```ruby
class Company < ApplicationRecord
  belongs_to :user
  has_many :products

  validates :name, presence: true
end
```

**Problem:** Without `acts_as_tenant`, queries like `Company.all` will return companies from ALL accounts, exposing data across tenants.

### ✅ Good - Includes acts_as_tenant

```ruby
class Company < ApplicationRecord
  acts_as_tenant :account

  belongs_to :user
  has_many :products

  validates :name, presence: true
end
```

**Result:** All queries automatically scoped to current tenant. `Company.all` only returns companies for the current account.

## Whitelisted Models

The following models are **intentionally cross-tenant** and do not need `acts_as_tenant`:

- `Account` - The tenant itself
- `User` - Users can belong to multiple accounts
- `ApplicationRecord` - Base class
- `ActionText::*` - Rails framework classes
- `ActiveStorage::*` - Rails framework classes
- Concerns in `app/models/concerns/` - Modules, not models

## Autocorrect

This cop has **safe autocorrect** that adds `acts_as_tenant :account` as the first line in the class body:

```bash
# Review violations
bin/rubocop --only ProspectsRadar/ModelMultiTenancy

# Auto-fix
bin/rubocop -a --only ProspectsRadar/ModelMultiTenancy
```

## Why This Matters

### Security Risk

```ruby
# WITHOUT acts_as_tenant
ActsAsTenant.with_tenant(acme_account) do
  Company.all  # ⚠️ Returns ALL companies from ALL accounts!
end

# WITH acts_as_tenant
ActsAsTenant.with_tenant(acme_account) do
  Company.all  # ✅ Returns only Acme's companies
end
```

### Data Leakage Scenario

1. Customer A views their dashboard
2. `Company.all` query runs
3. Without `acts_as_tenant`, Customer A sees Customer B's companies
4. **GDPR violation, security breach, customer trust lost**

## References

- **Architecture:** DEC-013 (Service-Controller Architecture)
- **Documentation:** `app/models/CLAUDE.md`
- **Tenant Gem:** `acts_as_tenant` gem documentation
- **Best Practices:** `AGENTS.md` - "ALL models must use acts_as_tenant"

## Configuration

```yaml
# .rubocop.yml
ProspectsRadar/ModelMultiTenancy:
  Enabled: true
  Include:
    - "app/models/**/*.rb"
  Exclude:
    - "app/models/concerns/**/*.rb"
    - "app/models/application_record.rb"
```

## Testing Multi-Tenancy

After fixing violations, verify tenant isolation:

```ruby
RSpec.describe Company do
  let(:account1) { create(:account) }
  let(:account2) { create(:account) }

  it "isolates data between tenants" do
    ActsAsTenant.with_tenant(account1) do
      create(:company, name: "Acme Corp")
    end

    ActsAsTenant.with_tenant(account2) do
      expect(Company.all).to be_empty  # Should not see Acme Corp
    end
  end
end
```

## Common Mistakes

### Mistake 1: Forgetting New Models

```ruby
# You create a new model
rails g model Product name:string

# ❌ BAD - Migration runs, model created, BUT no acts_as_tenant
class Product < ApplicationRecord
end

# ✅ GOOD - Add acts_as_tenant immediately
class Product < ApplicationRecord
  acts_as_tenant :account
end
```

### Mistake 2: Adding to Wrong Models

```ruby
# ❌ BAD - User should be cross-tenant
class User < ApplicationRecord
  acts_as_tenant :account  # WRONG - users belong to multiple accounts
end

# ✅ GOOD - User whitelisted, no acts_as_tenant
class User < ApplicationRecord
  has_many :account_users
  has_many :accounts, through: :account_users
end
```

### Mistake 3: Associations Without Tenant

```ruby
# ❌ BAD - Association points to non-tenant model
class Company < ApplicationRecord
  acts_as_tenant :account
  belongs_to :industry  # Industry model missing acts_as_tenant!
end

# ✅ GOOD - Both models tenant-scoped
class Company < ApplicationRecord
  acts_as_tenant :account
  belongs_to :industry
end

class Industry < ApplicationRecord
  acts_as_tenant :account
  has_many :companies
end
```

## Impact Assessment

Based on codebase analysis:

- **Models without acts_as_tenant:** ~5-10 (estimated)
- **Severity:** CRITICAL (data leakage)
- **Fix complexity:** Easy (autocorrect available)
- **Test impact:** None (should already be tested with tenants)

---

_Part of ProspectsRadar custom RuboCop cops - enforcing architecture at commit time_
