# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Architecture::ControllerServiceResultCheck, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when in controller file" do
    let(:source_file_path) { "app/controllers/companies_controller.rb" }

    it "registers offense for redirect after unchecked service call" do
      expect_offense(<<~RUBY, source_file_path)
        class CompaniesController < ApplicationController
          def create
            result = CompanyService.run(params)
            redirect_to companies_path
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ Architecture/ControllerServiceResultCheck: Service result must be checked with `.success?` or `.failure?` before render/redirect. [...]
          end
        end
      RUBY
    end

    it "does not register offense when result is checked" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompaniesController < ApplicationController
          def create
            result = CompanyService.run(params)
            if result.success?
              redirect_to companies_path
            else
              render :new
            end
          end
        end
      RUBY
    end

    it "does not register offense for auto_service_call" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompaniesController < ApplicationController
          def create
            auto_service_call
          end
        end
      RUBY
    end

    it "does not register offense without service call" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class CompaniesController < ApplicationController
          def index
            @companies = Company.all
            render :index
          end
        end
      RUBY
    end
  end

  context "when in application controller" do
    let(:source_file_path) { "app/controllers/application_controller.rb" }

    it "does not check application controller" do
      expect_no_offenses(<<~RUBY, source_file_path)
        class ApplicationController < ActionController::Base
          def create
            result = SomeService.run(params)
            redirect_to root_path
          end
        end
      RUBY
    end
  end
end
