# No Sleep in Cucumber - RuboCop Guide

## Why This Cop Exists

The `ProspectsRadar/NoSleepInCucumber` cop detects the use of `sleep` statements in Cucumber step definitions. Using `sleep` in tests is an **anti-pattern** that causes:

- ⏱️ **Slow tests** - Always waits the full duration, even if condition is met earlier
- 🐛 **Flaky tests** - May fail on slower machines or when system is under load
- 💸 **Wasted CI time** - Accumulates to significant time when running full suite
- 🔧 **Hard to maintain** - Arbitrary timeouts don't express intent

## The Problem

```ruby
# ❌ BAD - Arbitrary wait time
When('I click submit') do
  click_button 'Submit'
  sleep 2  # Hope 2 seconds is enough...
end
```

Issues with this approach:

1. **Always waits 2 seconds** - Even if page loads in 0.1 seconds
2. **May not be enough** - Could fail on slower systems
3. **Unclear intent** - What are we waiting for exactly?
4. **No feedback** - Doesn't tell you why it failed

## The Solution

Use Capybara's built-in waiting mechanisms that wait for **specific conditions**:

### 1. Wait for Element to Appear

```ruby
# ✅ GOOD - Wait for element
When('I click submit') do
  click_button 'Submit'
  expect(page).to have_selector('.success-message', wait: 5)
end
```

### 2. Wait for Path Change

```ruby
# ✅ GOOD - Wait for navigation
When('I click next') do
  click_button 'Next'
  expect(page).to have_current_path(next_step_path, wait: 5)
end
```

### 3. Wait for Text Content

```ruby
# ✅ GOOD - Wait for text
When('I submit the form') do
  click_button 'Submit'
  expect(page).to have_text('Success!', wait: 5)
end
```

### 4. Wait for Element to Disappear

```ruby
# ✅ GOOD - Wait for loading to finish
When('I load data') do
  click_button 'Load'
  expect(page).to have_no_selector('.loading-spinner', wait: 10)
end
```

### 5. Wait for Specific Count

```ruby
# ✅ GOOD - Wait for items to load
When('I view the list') do
  visit items_path
  expect(page).to have_selector('.item', count: 5, wait: 5)
end
```

## Common Patterns

### Pattern 1: Wait for Modal to Appear

```ruby
# ❌ BAD
click_link 'Open Modal'
sleep 0.5
expect(page).to have_selector('.modal')

# ✅ GOOD
click_link 'Open Modal'
expect(page).to have_selector('.modal', visible: true, wait: 5)
```

### Pattern 2: Wait for AJAX Request

```ruby
# ❌ BAD
click_button 'Load More'
sleep 1
expect(page).to have_text('New Item')

# ✅ GOOD
click_button 'Load More'
expect(page).to have_text('New Item', wait: 5)
```

### Pattern 3: Wait for Turbo Navigation

```ruby
# ❌ BAD
click_button 'Next Step'
sleep 2  # Wait for Turbo to navigate
expect(page).to have_current_path(step_2_path)

# ✅ GOOD
click_button 'Next Step'
expect(page).to have_current_path(step_2_path, wait: 5)
```

### Pattern 5: Wait for Turbo Frame Content (Wizard Steps)

```ruby
# ❌ BAD - sleep before checking wizard step title
sleep 0.5
expect(page).to have_css('h2', text: step_title, wait: 5)

# ✅ GOOD - wait for the Turbo Frame to be present first
expect(page).to have_css('turbo-frame#modal', wait: 5)
expect(page).to have_css('h2', text: step_title, wait: 5)
```

### Pattern 6: Wait for Validation Errors After Form Submit

```ruby
# ❌ BAD - sleep hoping validation has rendered
click_button 'Next'
sleep 1
expect(page).to have_css('.is-invalid')

# ✅ GOOD - let Capybara wait for the validation class
click_button 'Next'
expect(page).to have_css('.is-invalid, .invalid-feedback, .field-error', wait: 5)
```

### Pattern 4: Wait for Animation

```ruby
# ❌ BAD
click_button 'Toggle'
sleep 0.3  # Wait for animation
expect(page).to have_selector('.panel', visible: false)

# ✅ GOOD - Most animations complete before assertion
click_button 'Toggle'
expect(page).to have_selector('.panel', visible: false, wait: 2)

# ✅ BETTER - If testing animation state matters
click_button 'Toggle'
expect(page).to have_selector('.panel.animating', wait: 1)
expect(page).to have_no_selector('.panel.animating', wait: 2)
```

## When Sleep Might Be Acceptable

There are **rare cases** where `sleep` is acceptable:

1. **Simulating user behavior** (e.g., long press gestures)
2. **Testing time-based features** (e.g., auto-logout after inactivity)
3. **Rate limiting delays** (e.g., API throttling in integration tests)

For these cases, add a comment explaining why:

```ruby
# Acceptable - Simulating long press gesture
page.find('.element').click
sleep 0.5  # Long press requires 500ms hold
page.find('.element').release
```

## Disabling the Cop

If you have a legitimate reason to use `sleep`, disable the cop locally:

```ruby
# rubocop:disable ProspectsRadar/NoSleepInCucumber
sleep 0.5  # Required for gesture recognition
# rubocop:enable ProspectsRadar/NoSleepInCucumber
```

## Finding Violations

Run RuboCop to find all sleep violations:

```bash
# Check all step definitions
bin/rubocop features/step_definitions/ --only ProspectsRadar/NoSleepInCucumber

# Check specific file
bin/rubocop features/step_definitions/setup_steps.rb --only ProspectsRadar/NoSleepInCucumber
```

## Current Status

As of 2026-02-06, **all sleep calls have been removed from wizard step definitions** (6 removed from `company_profile_wizard_full.rb` and `wizard_navigation.rb`).

Remaining sleep calls fall into three categories:

- **Intentional wait atoms** (`features/step_definitions/atoms/waits.rb`) — by-design building blocks like "I wait a moment"
- **Polling helpers** (`features/support/helpers/`) — retry loops using sleep as backoff
- **Anti-patterns to fix** (`wizard_helper.rb:171`, `css_helper.rb:27`) — bare `sleep` with no retry

**Scope expanded:** The cop now also scans `features/support/helpers/` to catch sleep calls in helper methods.

## Migration Strategy

1. Run RuboCop to identify violations
2. For each violation, identify what condition you're waiting for
3. Replace with appropriate `have_selector`, `have_text`, or `have_current_path`
4. Test that the step still works reliably
5. Consider reducing wait times (start with 5 seconds, reduce if stable)

## Benefits

After removing sleep statements, you'll see:

- ⚡ **Faster test suite** - Tests complete as soon as conditions are met
- 🎯 **More reliable tests** - Explicit conditions reduce flakiness
- 📝 **Better intent** - Clear what each step is waiting for
- 🐛 **Better failures** - Know exactly which condition wasn't met

## References

- [Capybara Matchers](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Matchers)
- [Capybara Finders](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Finders)
- [Capybara Waiting](https://github.com/teamcapybara/capybara#asynchronous-javascript-ajax-and-friends)
