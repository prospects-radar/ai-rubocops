# frozen_string_literal: true

require "spec_helper"
require "rubocop/rspec/support"

RSpec.describe RuboCop::Cop::RSpec::NoLiveHttpConnections, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  describe "allow_http_connections_when_no_cassette" do
    it "registers an offense when it is switched on" do
      expect_offense(<<~RUBY, "spec/support/vcr.rb")
        VCR.configure do |config|
          config.allow_http_connections_when_no_cassette = true
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ RSpec/NoLiveHttpConnections: Do not allow live HTTP when no cassette is present. Any spec without a cassette then reaches the real host, which costs money and makes the suite wait rather than work. Gate it on ENV["VCR_RECORD"] instead.
        end
      RUBY
    end

    it "accepts it switched off" do
      expect_no_offenses(<<~RUBY, "spec/support/vcr.rb")
        config.allow_http_connections_when_no_cassette = false
      RUBY
    end

    it "accepts it gated on an environment variable" do
      expect_no_offenses(<<~RUBY, "spec/support/vcr.rb")
        config.allow_http_connections_when_no_cassette = ENV["VCR_RECORD"].present?
      RUBY
    end
  end

  describe "WebMock.allow_net_connect!" do
    it "registers an offense" do
      expect_offense(<<~RUBY, "spec/support/webmock_helpers.rb")
        def allow_external_requests!
          WebMock.allow_net_connect!
          ^^^^^^^^^^^^^^^^^^^^^^^^^^ RSpec/NoLiveHttpConnections: Do not call `WebMock.allow_net_connect!`. It lifts the block for everything that follows in the process, including specs that never asked for it. Stub the request, or record a cassette.
        end
      RUBY
    end

    it "accepts disable_net_connect!" do
      expect_no_offenses(<<~RUBY, "spec/support/webmock_helpers.rb")
        WebMock.disable_net_connect!(allow_localhost: true)
      RUBY
    end
  end

  describe "record: :new_episodes as a default" do
    it "registers an offense" do
      expect_offense(<<~RUBY, "spec/support/vcr.rb")
        config.default_cassette_options = { match_requests_on: [:method, :uri], record: :new_episodes }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ RSpec/NoLiveHttpConnections: Do not make `record: :new_episodes` the default cassette option. Every request a cassette does not already cover then goes to the real host and is appended to it. Use `:none` by default and gate recording on ENV["VCR_RECORD"]; a single cassette may still opt in.
      RUBY
    end

    it "accepts :none as the default" do
      expect_no_offenses(<<~RUBY, "spec/support/vcr.rb")
        config.default_cassette_options = { record: :none, allow_playback_repeats: true }
      RUBY
    end

    it "accepts a single cassette opting in" do
      expect_no_offenses(<<~RUBY, "spec/services/registry_spec.rb")
        it "talks to the registry", vcr: { record: :new_episodes } do
        end
      RUBY
    end
  end
end
