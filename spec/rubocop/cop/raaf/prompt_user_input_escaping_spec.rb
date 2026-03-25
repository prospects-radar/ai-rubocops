# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::PromptUserInputEscaping, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in prompt file" do
    let(:source_file_path) { "app/ai/prompts/company_analysis_prompt.rb" }

    it "registers offense for interpolated ivar in system prompt" do
      expect_offense(<<~RUBY, source_file_path)
        class CompanyAnalysisPrompt
          def system
            "You are analyzing \#{@company.name}. Respond in JSON."
                               ^^^^^^^^^^^^^^^^ RAAF/PromptUserInputEscaping: Avoid interpolating user data directly in system prompts. Place user-controlled data in the `user` prompt method instead, or use a sanitization helper.
          end
        end
      RUBY
    end

    it "does not register offense for user prompt" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyAnalysisPrompt
          def user
            "Analyze this company: \#{@company.name}"
          end
        end
      RUBY
    end

    it "does not register offense for static system prompt" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyAnalysisPrompt
          def system
            "You are a company analyst. Respond in JSON format."
          end
        end
      RUBY
    end

    it "does not register offense for safe interpolations in system prompt" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyAnalysisPrompt
          def system
            "You are running version \#{VERSION}. Today is \#{Date.current}."
          end
        end
      RUBY
    end
  end

  context "when not in prompt file" do
    let(:source_file_path) { "app/services/company_service.rb" }

    it "does not check non-prompt files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyService
          def system
            "Analyzing \#{@company.name}"
          end
        end
      RUBY
    end
  end
end
