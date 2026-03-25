# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::AgentSchemaValidation, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in agent file" do
    let(:source_file_path) { "app/ai/agents/prospect/analysis_agent.rb" }

    it "registers offense for schema without validation" do
      expect_offense(<<~RUBY, source_file_path)
        class AnalysisAgent < ApplicationAgent
              ^^^^^^^^^^^^^ RAAF/AgentSchemaValidation: Agent declares a schema but does not validate output against it. [...]
          def schema
            { type: "object" }
          end

          def process(result)
            result
          end
        end
      RUBY
    end

    it "does not register offense with validate_schema!" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class AnalysisAgent < ApplicationAgent
          def schema
            { type: "object" }
          end

          def process(result)
            validate_schema!(result)
            result
          end
        end
      RUBY
    end

    it "does not register offense with output_schema DSL" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class AnalysisAgent < ApplicationAgent
          output_schema AnalysisSchema

          def schema
            { type: "object" }
          end
        end
      RUBY
    end

    it "does not register offense without schema definition" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class AnalysisAgent < ApplicationAgent
          def process(result)
            result
          end
        end
      RUBY
    end
  end

  context "when not in agent file" do
    let(:source_file_path) { "app/services/company_service.rb" }

    it "does not check non-agent files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompanyService < BaseService
          def schema
            { type: "object" }
          end
        end
      RUBY
    end
  end
end
