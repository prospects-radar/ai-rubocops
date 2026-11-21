# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::PromptUntrustedTextWrapped, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  def message(source)
    "RAAF/PromptUntrustedTextWrapped: `#{source}` is third-party text interpolated without `xml_wrap_untrusted`. " \
      "Wrap it, and keep ThirdPartyText::RULE in the system prompt."
  end

  it "flags a search snippet rendered as a plain line (#1649)" do
    expect_offense(<<~'RUBY'.sub("MSG", message("result[:snippet]")))
      "- Snippet: #{result[:snippet]}"
                    ^^^^^^^^^^^^^^^^ MSG
    RUBY
  end

  it "flags string keys, dig and method reads", :aggregate_failures do
    source = <<~'RUBY'
      "#{event["description"]}"
         ^^^^^^^^^^^^^^^^^^^^ MSG1
      "#{company.dig(:linkedin, :posts)}"
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ MSG2
      "Bio: #{person.bio.to_s.strip}"
              ^^^^^^^^^^ MSG3
    RUBY

    expect_offense(source.sub("MSG1", message('event["description"]'))
                         .sub("MSG2", message("company.dig(:linkedin, :posts)"))
                         .sub("MSG3", message("person.bio")))
  end

  it "flags a bare news_content context read" do
    expect_offense(<<~'RUBY'.sub("MSG", message("news_content")))
      "News: #{news_content}"
               ^^^^^^^^^^^^ MSG
    RUBY
  end

  it "accepts text escaped inside the interpolation" do
    expect_no_offenses(<<~'RUBY')
      "- Snippet: #{escape_xml(result[:snippet].to_s)}"
    RUBY
  end

  it "accepts a string that is itself handed to xml_wrap_untrusted" do
    expect_no_offenses(<<~'RUBY')
      xml_wrap_untrusted("result", "Snippet: #{result[:snippet]}\nURL: #{result[:url]}")
    RUBY
  end

  it "accepts fields that are not third-party text" do
    expect_no_offenses(<<~'RUBY')
      "#{result[:url]} #{company[:name]} #{content_section} #{text}"
    RUBY
  end

  context "with a configured field list" do
    let(:config) do
      RuboCop::Config.new("AllCops" => { "DisplayCopNames" => true },
                          "RAAF/PromptUntrustedTextWrapped" => { "Fields" => %w[headline] })
    end

    it "checks the configured fields instead", :aggregate_failures do
      expect_offense(<<~'RUBY'.sub("MSG", message("profile[:headline]")))
        "#{profile[:headline]} #{result[:snippet]}"
           ^^^^^^^^^^^^^^^^^^ MSG
      RUBY
    end
  end
end
