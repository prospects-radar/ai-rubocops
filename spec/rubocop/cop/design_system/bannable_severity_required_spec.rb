# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::DesignSystem::BannableSeverityRequired, :config do
  subject(:cop) { described_class.new(config) }

  it "registers an offense when Bannable included but severity not declared" do
    expect_offense(<<~RUBY)
      class MyBanner < BaseComponent
        include Bannable
        ^^^^^^^^^^^^^^^^ BannableSeverityRequired: class includes Bannable but does not declare `severity`. Add `severity :critical`, `:warning`, or `:info`.
      end
    RUBY
  end

  it "allows class that declares severity via class macro" do
    expect_no_offenses(<<~RUBY)
      class MyBanner < BaseComponent
        include Bannable
        severity :warning
      end
    RUBY
  end

  it "allows class that overrides severity as instance method" do
    expect_no_offenses(<<~RUBY)
      class MyBanner < BaseComponent
        include Bannable

        def severity
          @level == :critical ? :critical : :warning
        end
      end
    RUBY
  end

  it "ignores classes that do not include Bannable" do
    expect_no_offenses(<<~RUBY)
      class MyComponent < BaseComponent
      end
    RUBY
  end
end
