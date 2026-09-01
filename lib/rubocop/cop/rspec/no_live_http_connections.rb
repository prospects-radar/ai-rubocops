# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Forbids re-opening the network from the test suite's configuration.
      #
      # A suite that can reach the internet is slow in a way no amount of
      # hardware fixes, and expensive in a way nothing reports. Waiting on a
      # remote API burns no CPU, so the machine looks idle while a worker sits
      # on a socket; adding workers cannot help, because the wait is not work.
      # And every run pays whatever the far end charges.
      #
      # `WebMock.disable_net_connect!` is not enough on its own. Once VCR is
      # hooked into WebMock it answers first, so a VCR setting can open a door
      # WebMock believes it has shut, with nothing in the output to say so.
      # Measured on this suite: four specs with no cassette and no stub made
      # live calls to a paid AI API and accounted for 53% of the whole run.
      #
      # Three settings do it, and each is flagged:
      #
      # `allow_http_connections_when_no_cassette` lets any request outside a
      # cassette through to the real host. `WebMock.allow_net_connect!` lifts
      # the block outright. And `record: :new_episodes` as a *default* cassette
      # option sends any request a cassette does not already cover to the real
      # host and appends the answer, so cassettes grow live traffic on their
      # own. On a single cassette that mode is a deliberate recording choice
      # and stays allowed; as the default for every cassette it is the leak.
      #
      # Recording new cassettes still has to be possible. Gate it on an
      # environment variable so it is something a person turns on for one run,
      # rather than the state the suite sits in.
      #
      # @example
      #   # bad - any request without a cassette reaches the real host
      #   VCR.configure do |config|
      #     config.allow_http_connections_when_no_cassette = true
      #   end
      #
      #   # bad - lifts the block for everything that follows
      #   WebMock.allow_net_connect!
      #
      #   # bad - every cassette records what it does not already have
      #   config.default_cassette_options = { record: :new_episodes }
      #
      #   # good - closed by default, opened deliberately for a recording run
      #   recording = ENV["VCR_RECORD"].present?
      #   config.allow_http_connections_when_no_cassette = recording
      #   config.default_cassette_options = {
      #     record: recording ? :new_episodes : :none
      #   }
      #
      #   # good - one cassette recorded on purpose
      #   it "talks to the registry", vcr: { record: :new_episodes } do
      #   end
      #
      class NoLiveHttpConnections < Base
        MSG_NO_CASSETTE =
          "Do not allow live HTTP when no cassette is present. Any spec without a " \
          "cassette then reaches the real host, which costs money and makes the " \
          "suite wait rather than work. Gate it on ENV[\"VCR_RECORD\"] instead."

        MSG_ALLOW_NET =
          "Do not call `WebMock.allow_net_connect!`. It lifts the block for " \
          "everything that follows in the process, including specs that never " \
          "asked for it. Stub the request, or record a cassette."

        MSG_NEW_EPISODES =
          "Do not make `record: :new_episodes` the default cassette option. Every " \
          "request a cassette does not already cover then goes to the real host " \
          "and is appended to it. Use `:none` by default and gate recording on " \
          "ENV[\"VCR_RECORD\"]; a single cassette may still opt in."

        RESTRICT_ON_SEND = %i[
          allow_http_connections_when_no_cassette=
          allow_net_connect!
          default_cassette_options=
        ].freeze

        # config.allow_http_connections_when_no_cassette = true
        def_node_matcher :allow_when_no_cassette?, <<~PATTERN
          (send _ :allow_http_connections_when_no_cassette= true)
        PATTERN

        # WebMock.allow_net_connect!
        def_node_matcher :allow_net_connect?, <<~PATTERN
          (send (const {nil? cbase} :WebMock) :allow_net_connect! ...)
        PATTERN

        # config.default_cassette_options = { record: :new_episodes, ... }
        def_node_matcher :default_new_episodes?, <<~PATTERN
          (send _ :default_cassette_options= (hash <(pair (sym :record) (sym :new_episodes)) ...>))
        PATTERN

        def on_send(node)
          if allow_when_no_cassette?(node)
            add_offense(node, message: MSG_NO_CASSETTE)
          elsif allow_net_connect?(node)
            add_offense(node, message: MSG_ALLOW_NET)
          elsif default_new_episodes?(node)
            add_offense(node, message: MSG_NEW_EPISODES)
          end
        end
      end
    end
  end
end
