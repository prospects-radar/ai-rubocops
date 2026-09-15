# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::Architecture::NoSubstringIdentityMatch, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context "when a LIKE on an identity column is reduced to one row" do
    it "flags the shape #1055 removed" do
      expect_offense(<<~'RUBY')
        Company.where("LOWER(companies.website) LIKE ?", "%#{domain}%").first
                ^^^^^ Architecture/NoSubstringIdentityMatch: A `LIKE` on `website` picked down to one row is a substring, not an identity test (#926, #934, #1055). Resolve through `Companies::ResolveCompany` — it matches the host at its boundaries and breaks ties with `order(:id)`.
      RUBY
    end

    it "flags an ILIKE ANY whose wildcards live in the bound array" do
      expect_offense(<<~RUBY)
        Company.where(account: account).where("website ILIKE ANY (ARRAY[?])", patterns).first
                                        ^^^^^ Architecture/NoSubstringIdentityMatch: A `LIKE` on `website` picked down to one row is a substring, not an identity test (#926, #934, #1055). Resolve through `Companies::ResolveCompany` — it matches the host at its boundaries and breaks ties with `order(:id)`.
      RUBY
    end

    it "flags the domain column too" do
      expect_offense(<<~'RUBY')
        Company.where("domain LIKE ?", "%#{value}%").take
                ^^^^^ Architecture/NoSubstringIdentityMatch: A `LIKE` on `domain` picked down to one row is a substring, not an identity test (#926, #934, #1055). Resolve through `Companies::ResolveCompany` — it matches the host at its boundaries and breaks ties with `order(:id)`.
      RUBY
    end

    it "flags find_by, which is a finder in its own right" do
      expect_offense(<<~'RUBY')
        Company.find_by("website LIKE ?", "%#{domain}%")
                ^^^^^^^ Architecture/NoSubstringIdentityMatch: A `LIKE` on `website` picked down to one row is a substring, not an identity test (#926, #934, #1055). Resolve through `Companies::ResolveCompany` — it matches the host at its boundaries and breaks ties with `order(:id)`.
      RUBY
    end

    it "sees through relation links that keep it a relation" do
      expect_offense(<<~'RUBY')
        Company.where("website LIKE ?", "%#{domain}%").order(:id).limit(1).first
                ^^^^^ Architecture/NoSubstringIdentityMatch: A `LIKE` on `website` picked down to one row is a substring, not an identity test (#926, #934, #1055). Resolve through `Companies::ResolveCompany` — it matches the host at its boundaries and breaks ties with `order(:id)`.
      RUBY
    end
  end

  context "when the result stays a relation" do
    it "accepts a search filter assigned back to a scope" do
      expect_no_offenses(<<~'RUBY')
        scope = scope.where("LOWER(website) LIKE ?", "%#{domain}%")
      RUBY
    end

    it "accepts a filter the caller pages over" do
      expect_no_offenses(<<~'RUBY')
        Company.where("website LIKE ?", "%#{domain}%").limit(10).map { |c| payload(c) }
      RUBY
    end
  end

  context "when the column is not a hard identity key" do
    it "accepts a fuzzy name match picked down to one row" do
      expect_no_offenses(<<~'RUBY')
        Company.where("name ILIKE ?", "%#{company_name}%").first
      RUBY
    end

    it "does not trip on a column whose name merely ends in one" do
      expect_no_offenses(<<~'RUBY')
        Company.where("buyer_domain_label LIKE ?", "%#{value}%").first
      RUBY
    end
  end

  context "when the comparison is not a LIKE" do
    it "accepts an equality on the host" do
      expect_no_offenses(<<~RUBY)
        scope.where("\#{WEBSITE_HOST} = :domain", domain: domain_value).order(:id).first
      RUBY
    end
  end

  context "with IdentityColumns configured" do
    let(:config) do
      RuboCop::Config.new(
        "Architecture/NoSubstringIdentityMatch" => { "IdentityColumns" => %w[linkedin_url] }
      )
    end

    it "flags only the configured columns" do
      expect_no_offenses(<<~'RUBY')
        Company.where("website LIKE ?", "%#{domain}%").first
      RUBY
    end
  end
end
