# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Convention::NoDoubleDecodeHashedId, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when re-decoding a top-level param" do
    it "flags Model.decode_param(params[:key])" do
      expect_offense(<<~RUBY)
        Prospect.decode_param(params[:prospect_id])
                 ^^^^^^^^^^^^ Convention/NoDoubleDecodeHashedId: `params[:prospect_id]` is already decoded by DecodesHashedIds — don't `decode_param` it again (re-decoding a raw PK returns nil). Use the value directly or `Model.find(params[:prospect_id])`.
      RUBY
    end

    it "flags resolve_param_to_id(params[:key])" do
      expect_offense(<<~RUBY)
        Company.resolve_param_to_id(params[:company_id])
                ^^^^^^^^^^^^^^^^^^^ Convention/NoDoubleDecodeHashedId: `params[:company_id]` is already decoded by DecodesHashedIds — don't `resolve_param_to_id` it again (re-decoding a raw PK returns nil). Use the value directly or `Model.find(params[:company_id])`.
      RUBY
    end

    it "flags from_param(params[:key])" do
      expect_offense(<<~RUBY)
        Task.from_param(params[:task_id])
             ^^^^^^^^^^ Convention/NoDoubleDecodeHashedId: `params[:task_id]` is already decoded by DecodesHashedIds — don't `from_param` it again (re-decoding a raw PK returns nil). Use the value directly or `Model.find(params[:task_id])`.
      RUBY
    end

    it "flags params.fetch too" do
      expect_offense(<<~RUBY)
        Product.decode_param(params.fetch(:product_id))
                ^^^^^^^^^^^^ Convention/NoDoubleDecodeHashedId: `params[:product_id]` is already decoded by DecodesHashedIds — don't `decode_param` it again (re-decoding a raw PK returns nil). Use the value directly or `Model.find(params[:product_id])`.
      RUBY
    end
  end

  context "when the decode is legitimate" do
    it "does not flag nested params.dig (concern does not decode those)" do
      expect_no_offenses(<<~RUBY)
        Product.decode_param(params.dig(:wizard_data, :product_id))
      RUBY
    end

    it "does not flag nested params[:a][:b]" do
      expect_no_offenses(<<~RUBY)
        Product.decode_param(params[:wizard_data][:product_id])
      RUBY
    end

    it "does not flag decoding a plain string variable" do
      expect_no_offenses(<<~RUBY)
        Prospect.decode_param(token)
      RUBY
    end

    it "does not flag using the param directly" do
      expect_no_offenses(<<~RUBY)
        Prospect.find(params[:prospect_id])
      RUBY
    end
  end
end
