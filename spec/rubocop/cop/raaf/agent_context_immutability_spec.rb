# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::AgentContextImmutability, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in agent file" do
    let(:source_file_path) { "app/ai/agents/prospect/scorer.rb" }

    it "registers offense for bracket assignment on context" do
      expect_offense(<<~RUBY, source_file_path)
        class Scorer < ApplicationAgent
          def execute(context)
            context[:score] = 42
            ^^^^^^^^^^^^^^^^^^^^ RAAF/AgentContextImmutability: Do not mutate shared agent context directly. [...]
          end
        end
      RUBY
    end

    it "registers offense for merge! on context" do
      expect_offense(<<~RUBY, source_file_path)
        class Scorer < ApplicationAgent
          def execute(context)
            context.merge!(score: 42)
            ^^^^^^^^^^^^^^^^^^^^^^^^^ RAAF/AgentContextImmutability: Do not use `merge!` or `update` on agent context. [...]
          end
        end
      RUBY
    end

    it "does not register offense when returning new data" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Scorer < ApplicationAgent
          def execute(context)
            { score: calculate_score(context[:data]) }
          end
        end
      RUBY
    end

    it "does not register offense for methods without context param" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Scorer < ApplicationAgent
          def execute(data)
            data[:score] = 42
          end
        end
      RUBY
    end

    it "does not register offense for non-execution methods" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class Scorer < ApplicationAgent
          def build_params(context)
            context[:score] = 42
          end
        end
      RUBY
    end
  end

  context "when not in agent file" do
    let(:source_file_path) { "app/services/my_service.rb" }

    it "does not check non-agent files" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class MyService < BaseService
          def execute(context)
            context[:result] = "done"
          end
        end
      RUBY
    end
  end
end
