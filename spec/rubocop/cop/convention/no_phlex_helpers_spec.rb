# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Convention::NoPhlexHelpers, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it "flags a chained helpers call" do
    expect_offense(<<~RUBY)
      helpers.params[:tab]
      ^^^^^^^ Convention/NoPhlexHelpers: phlex-rails deprecated `helpers`. Use `view_context`, a `Phlex::Rails::Helpers::*` module, or `register_value_helper` instead.
    RUBY
  end

  it "flags a bare helpers call" do
    expect_offense(<<~RUBY)
      format_with(helpers)
                  ^^^^^^^ Convention/NoPhlexHelpers: phlex-rails deprecated `helpers`. Use `view_context`, a `Phlex::Rails::Helpers::*` module, or `register_value_helper` instead.
    RUBY
  end

  it "accepts view_context" do
    expect_no_offenses("view_context.request.fullpath")
  end

  it "accepts helpers on an explicit receiver" do
    expect_no_offenses("ActionController::Base.helpers.sanitize(html)")
  end

  it "accepts a local variable named helpers" do
    expect_no_offenses(<<~RUBY)
      helpers = build_helpers
      helpers.call
    RUBY
  end
end
