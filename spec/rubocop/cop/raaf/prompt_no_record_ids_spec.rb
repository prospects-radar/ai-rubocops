# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RAAF::PromptNoRecordIds, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:msg) do
    "RAAF/PromptNoRecordIds: Prompt text renders the record id `%s`. " \
      "An id means nothing to the model: render a fact, or a positional handle mapped back in Ruby."
  end

  it "flags an id interpolated into prompt text" do
    expect_offense(<<~'RUBY')
      "Event #{event[:id]}: #{event[:title]}"
               ^^^^^^^^^^ RAAF/PromptNoRecordIds: Prompt text renders the record id `event[:id]`. An id means nothing to the model: render a fact, or a positional handle mapped back in Ruby.
    RUBY
  end

  it "flags an id as the value of a payload hash" do
    expect_offense(<<~RUBY)
      { id: company[:id], name: company[:name] }.to_json
            ^^^^^^^^^^^^ #{format(msg, "company[:id]")}
    RUBY
  end

  it "flags a foreign key read by method or string key", :aggregate_failures do
    expect_offense(<<~RUBY)
      { product: prospect.product_id, company: row["company_id"] }
                 ^^^^^^^^^^^^^^^^^^^ #{format(msg, "prospect.product_id")}
                                               ^^^^^^^^^^^^^^^^^ #{format(msg, 'row["company_id"]')}
    RUBY
  end

  it "flags an id passed through to_s on its way into the text" do
    expect_offense(<<~'RUBY')
      "(ID: #{event.id.to_s})"
              ^^^^^^^^ RAAF/PromptNoRecordIds: Prompt text renders the record id `event.id`. An id means nothing to the model: render a fact, or a positional handle mapped back in Ruby.
    RUBY
  end

  it "leaves an id used for a lookup alone" do
    expect_no_offenses(<<~RUBY)
      events.find { |event| event[:id] == wanted }
      by_id = events.index_by { |event| event[:id] }
    RUBY
  end

  it "leaves a positional handle alone" do
    expect_no_offenses(<<~'RUBY')
      "E#{index + 1}: #{event[:title]}"
    RUBY
  end
end
