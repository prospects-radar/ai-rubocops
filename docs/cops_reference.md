# Custom RuboCop Cops

This document describes the custom RuboCop cops that enforce ProspectsRadar's architectural standards.

## Table of Contents

1. [High Priority Cops](#high-priority-cops)
2. [Medium Priority Cops](#medium-priority-cops)
3. [Low Priority Cops](#low-priority-cops)
4. [How to Fix Violations](#how-to-fix-violations)
5. [Running the Cops](#running-the-cops)

## High Priority Cops

### Architecture/ServiceInheritance

**Purpose:** Ensures all services inherit from `BaseService` to maintain consistent service architecture.

**Why:** Services must follow the action-dispatch pattern defined in BaseService (DEC-013).

**Bad:**

```ruby
class MyService
  def call
    # service logic
  end
end
```

**Good:**

```ruby
class MyService < BaseService
  private

  def create
    success_result(resource: Resource.new)
  end
end
```

**Auto-fixable:** Yes - adds `< BaseService` to class definition

### Architecture/NoCurrentUserParameter

**Purpose:** Prevents services from accepting `current_user` as a parameter.

**Why:** Services should access the current user via `Current.current_user` (set by ApplicationController).

**Bad:**

```ruby
class MyService < BaseService
  def initialize(current_user:, other_param:)
    @current_user = current_user
  end
end
```

**Good:**

```ruby
class MyService < BaseService
  def initialize(other_param:)
    @other_param = other_param
  end

  private

  def create
    user = Current.current_user
    # use user
  end
end
```

**Auto-fixable:** No - requires manual refactoring

### Architecture/I18nNoDefault

**Purpose:** Enforces strict I18n mode - no default parameters allowed.

**Why:** All translations must exist in locale files. Prevents hardcoded English text.

**Bad:**

```ruby
flash[:notice] = I18n.t("company.created", default: "Company created successfully")
```

**Good:**

```ruby
flash[:notice] = I18n.t("company.created")
# Ensure key exists in config/locales/en.yml
```

**Auto-fixable:** Yes - removes default parameter (but you must add translations)

### Architecture/ServiceActionDispatch

**Purpose:** Prevents old-style `call` methods with case statements in services.

**Why:** Services use action-based dispatch pattern, not case statements.

**Bad:**

```ruby
class MyService < BaseService
  def call
    case action
    when :create then create_resource
    when :update then update_resource
    end
  end
end
```

**Good:**

```ruby
class MyService < BaseService
  private

  def create
    # create logic
  end

  def update
    # update logic
  end
end
```

**Auto-fixable:** No - requires manual refactoring

### Architecture/ControllerBusinessLogic

**Purpose:** Ensures controllers remain thin with no business logic.

**Why:** Controllers should only authenticate, delegate to services, and handle responses.

**Bad:**

```ruby
class CompaniesController < ApplicationController
  def create
    company = Company.new(company_params)

    if company.valid?
      company.save!

      # Complex logic
      if company.premium?
        EmailService.send_premium_welcome(company)
        AnalyticsService.track_premium_signup(company)
      end

      redirect_to company
    else
      render :new
    end
  end
end
```

**Good:**

```ruby
class CompaniesController < ApplicationController
  include AutoServiceResponse

  def create
    auto_service_call  # Delegates to CompanyService#create
  end
end
```

**Auto-fixable:** No - requires extracting logic to services

## Medium Priority Cops

### RAAF/AgentRun

**Purpose:** Ensures RAAF agents are executed with `.run` not `.call`.

**Why:** RAAF framework convention - agents use `.run` for execution.

**Bad:**

```ruby
result = CompanyAnalyzerAgent.call(company: company)
```

**Good:**

```ruby
result = CompanyAnalyzerAgent.run(company: company)
```

**Auto-fixable:** Yes - replaces `.call` with `.run`

### Convention/FrozenStringLiteral

**Purpose:** Ensures frozen string literal pragma is present.

**Why:** Performance and memory optimization.

**Status:** Currently disabled - use `Style/FrozenStringLiteralComment` instead.

## Low Priority Cops

### Architecture/ServiceResponseFormat

**Purpose:** Ensures service methods return `success_result` or `error_result`.

**Why:** Consistent API for service responses across the application.

**Bad:**

```ruby
def create
  company = Company.create!(params)
  company  # Returns raw object
end
```

**Good:**

```ruby
def create
  company = Company.create!(params)
  success_result(resource: company)
rescue => e
  error_result(e.message)
end
```

**Exceptions:**

- Private helper methods
- Finder methods (`find_by_id`, etc.)
- Guard clauses returning nil/false/true
- Predicate methods (ending with `?`)

**Auto-fixable:** No - requires manual wrapping

### RAAF/PromptMethods

**Purpose:** Ensures RAAF prompts define `system` and `user` methods.

**Why:** RAAF DSL requires these methods for prompt structure.

**Bad:**

```ruby
class MyPrompt < RAAF::DSL::Prompts::Base
  def prompt
    "Do something"
  end
end
```

**Good:**

```ruby
class MyPrompt < RAAF::DSL::Prompts::Base
  def system
    "You are a helpful assistant"
  end

  def user
    "Analyze this: #{context[:input]}"
  end
end
```

**Auto-fixable:** No - requires implementing methods

### RAAF/AgentInheritance

**Purpose:** Ensures AI agents inherit from `ApplicationAgent`.

**Why:** ApplicationAgent provides common configuration and error handling.

**Bad:**

```ruby
class MyAgent < RAAF::Agent
  # agent logic
end
```

**Good:**

```ruby
class MyAgent < ApplicationAgent
  # agent logic
end
```

**Auto-fixable:** Yes - changes parent class

## How to Fix Violations

### Quick Fixes

```bash
# Fix all auto-fixable violations
bundle exec rubocop -a

# Fix specific cop violations
bundle exec rubocop -a --only Architecture/ServiceInheritance
```

### Manual Fixes

For violations that can't be auto-fixed:

1. **NoCurrentUserParameter**: Remove parameter, use `Current.current_user`
2. **ServiceActionDispatch**: Refactor case statement to private methods
3. **ControllerBusinessLogic**: Extract logic to service, use `auto_service_call`
4. **ServiceResponseFormat**: Wrap returns in `success_result`/`error_result`

## Running the Cops

```bash
# Run all cops in a category
bundle exec rubocop --only Architecture
bundle exec rubocop --only RAAF

# Run specific cop
bundle exec rubocop --only Architecture/ServiceInheritance

# Run on specific directory
bundle exec rubocop --only Architecture app/services/

# Generate TODO file for gradual fixing
bundle exec rubocop --auto-gen-config --only Architecture
```

## Troubleshooting

### Cop Crashes or Errors

If you see an error like:

```
An error occurred while Architecture/[CopName] cop was inspecting...
```

1. Run with debug flag to see full backtrace:

   ```bash
   bundle exec rubocop -d --only Architecture/[CopName] path/to/file.rb
   ```

2. Common issues:
   - **`undefined method 'unless_type?'`**: Fixed - `unless` is represented as `if` in RuboCop AST
   - **Infinite loops**: Check that cops don't trigger on their own fixes
   - **False positives**: Add exclusions to `.rubocop.yml`
