# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Convention::EncodeRecordIdsInViews, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "with a registry-backed *_id param" do
    it "flags raw .id and autocorrects to to_param" do
      expect_offense(<<~RUBY)
        new_task_path(prospect_id: @prospect.id)
                                             ^^ Convention/EncodeRecordIdsInViews: Emit `to_param` (encoded id), not raw `.id`, under `prospect_id:` — raw primary keys leak past the encoded-id boundary and 404 on decode. See HashedId.
      RUBY

      expect_correction(<<~RUBY)
        new_task_path(prospect_id: @prospect.to_param)
      RUBY
    end

    it "flags a local receiver too" do
      expect_offense(<<~RUBY)
        link_to "x", company_path(company_id: company.id)
                                                      ^^ Convention/EncodeRecordIdsInViews: Emit `to_param` (encoded id), not raw `.id`, under `company_id:` — raw primary keys leak past the encoded-id boundary and 404 on decode. See HashedId.
      RUBY
    end
  end

  context "with a dom-id / :id key" do
    it "flags raw .id inside string interpolation" do
      expect_offense(<<~'RUBY')
        FlexRow(id: "prospect-#{prospect.id}")
                                         ^^ Convention/EncodeRecordIdsInViews: Emit `to_param` (encoded id), not raw `.id`, under `id:` — raw primary keys leak past the encoded-id boundary and 404 on decode. See HashedId.
      RUBY

      expect_correction(<<~'RUBY')
        FlexRow(id: "prospect-#{prospect.to_param}")
      RUBY
    end

    it "flags a bare :id value" do
      expect_offense(<<~RUBY)
        { id: prospect.id, name: prospect.name }
                       ^^ Convention/EncodeRecordIdsInViews: Emit `to_param` (encoded id), not raw `.id`, under `id:` — raw primary keys leak past the encoded-id boundary and 404 on decode. See HashedId.
      RUBY
    end

    it "flags testid interpolation" do
      expect_offense(<<~'RUBY')
        Item(testid: "delegate-#{user.id}")
                                      ^^ Convention/EncodeRecordIdsInViews: Emit `to_param` (encoded id), not raw `.id`, under `testid:` — raw primary keys leak past the encoded-id boundary and 404 on decode. See HashedId.
      RUBY
    end
  end

  context "when the id is legitimately raw" do
    it "does not flag ActiveRecord query conditions" do
      expect_no_offenses(<<~RUBY)
        Prospect.find_by(prospect_company_id: company.id)
      RUBY
    end

    it "does not flag where clauses on :id" do
      expect_no_offenses(<<~RUBY)
        Stakeholder.where(id: ids)
      RUBY
    end

    it "does not flag i18n interpolation" do
      expect_no_offenses(<<~RUBY)
        t("gdpr.requests.show.request_id", id: @request.id)
      RUBY
    end

    it "does not flag excluded user-scoped id keys" do
      expect_no_offenses(<<~RUBY)
        assign(assigned_to_id: user.id)
      RUBY
    end

    it "does not flag internal FK prospect_company_id outside a query" do
      expect_no_offenses(<<~RUBY)
        build(prospect_company_id: company.id)
      RUBY
    end

    it "does not flag a non-id key" do
      expect_no_offenses(<<~RUBY)
        render(name: prospect.id)
      RUBY
    end

    it "does not flag Model.id (const receiver)" do
      expect_no_offenses(<<~RUBY)
        cache(company_id: Company.id)
      RUBY
    end

    it "does not flag values already using to_param" do
      expect_no_offenses(<<~RUBY)
        new_task_path(prospect_id: @prospect.to_param)
      RUBY
    end
  end
end
