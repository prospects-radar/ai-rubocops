# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Cucumber::PreferAtomicSteps, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in organism step definitions" do
    let(:source_file_path) { "features/step_definitions/organisms/authentication.rb" }

    it "registers offense for find().click" do
      expect_offense(<<~RUBY, source_file_path)
        When('I log out') do
          find('[data-testid="logout"]').click
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Cucumber/PreferAtomicSteps: Use atomic/molecule step composition (step '...') instead of find(). Only atoms/ and universal/ directories can use Capybara directly.
        end
      RUBY
    end

    it "registers offense for find_field" do
      expect_offense(<<~RUBY, source_file_path)
        Then('the field should be empty') do
          field = find_field('email')
                  ^^^^^^^^^^^^^^^^^^^ Cucumber/PreferAtomicSteps: Use atomic/molecule step composition (step '...') instead of find(). Only atoms/ and universal/ directories can use Capybara directly.
          expect(field.value).to be_blank
        end
      RUBY
    end

    it "does not register offense for step delegation" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I log in with valid credentials') do
          step 'I visit "login"'
          step 'I fill in "email" with "test@example.com"'
          step 'I click "Submit"'
        end
      RUBY
    end

    it "does not register offense for expect() with matchers" do
      expect_no_offenses(<<~RUBY, source_file_path)
        Then('I should see the login form') do
          expect(page).to have_css('.login-form')
          expect(page).to have_button('Submit')
        end
      RUBY
    end

    it "does not register offense for with_tenant helper" do
      expect_no_offenses(<<~RUBY, source_file_path)
        Given('I have a company') do
          with_tenant(current_account) do
            @company = create(:company)
          end
        end
      RUBY
    end

    it "does not register offense for custom helpers" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I fill in industry') do
          fill_in_or_select_industry('Technology')
        end
      RUBY
    end

    it "does not register offense for FactoryBot methods" do
      expect_no_offenses(<<~RUBY, source_file_path)
        Given('the following user exists:') do |table|
          table.hashes.each do |row|
            create(:user, email: row['email'])
          end
        end
      RUBY
    end

    it "does not register offense for visit" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I navigate to dashboard') do
          visit dashboard_path
        end
      RUBY
    end

    it "does not register offense for query methods" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I check if modal is visible') do
          if page.has_css?('.modal', wait: 2)
            puts 'Modal is visible'
          end
        end
      RUBY
    end
  end

  context "when in molecule step definitions" do
    let(:source_file_path) { "features/step_definitions/molecules/modals.rb" }

    it "registers offense for find().click in molecules" do
      expect_offense(<<~RUBY, source_file_path)
        When('I confirm the modal') do
          find('[data-testid="confirm"]').click
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Cucumber/PreferAtomicSteps: Use atomic/molecule step composition (step '...') instead of find(). Only atoms/ and universal/ directories can use Capybara directly.
        end
      RUBY
    end

    it "does not register offense for step composition" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I confirm the modal') do
          step 'I click "confirm"'
        end
      RUBY
    end
  end

  context "when in atom step definitions" do
    let(:source_file_path) { "features/step_definitions/atoms/clicks.rb" }

    it "does not register offense for direct Capybara in atoms" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I click {string}') do |element|
          find_element_smart(element).click
        end
      RUBY
    end

    it "does not register offense for find() in atoms" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I click the button') do
          find('[data-testid="button"]').click
        end
      RUBY
    end

    it "does not register offense for click_button in atoms" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I submit') do
          click_button 'Submit'
        end
      RUBY
    end
  end

  context "when in universal step definitions" do
    let(:source_file_path) { "features/step_definitions/universal/field_steps.rb" }

    it "does not register offense for direct Capybara in universal" do
      expect_no_offenses(<<~RUBY, source_file_path)
        When('I fill in the field') do
          fill_in 'email', with: 'test@example.com'
        end
      RUBY
    end
  end

  context "when in support files" do
    let(:source_file_path) { "features/support/helpers.rb" }

    it "does not register offense for helper methods" do
      expect_no_offenses(<<~RUBY, source_file_path)
        def fill_in_or_select_industry(value)
          find('#industry').select(value)
        end
      RUBY
    end
  end

  context "when in non-Cucumber files" do
    let(:source_file_path) { "spec/models/user_spec.rb" }

    it "does not check non-cucumber files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        it 'works' do
          click_button 'Submit'
          find('.button').click
        end
      RUBY
    end
  end
end
