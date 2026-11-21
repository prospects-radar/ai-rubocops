# frozen_string_literal: true

module RuboCop
  module Cop
    module RAAF
      # Flags third-party text interpolated into a prompt string without
      # `xml_wrap_untrusted`.
      #
      # Search snippets, page text, company descriptions, posts, bios and news
      # are written by whoever published them. Interpolated as they are, a
      # snippet holding `</events>` or a line shaped like the prompt's own
      # markup ("#122133 [projects] ...", "confidence 1.0") reads as part of
      # the prompt (#1649). `xml_wrap_untrusted` escapes the text and puts it
      # inside a tag the prompt's data-only rule can name.
      #
      # Flagged: an interpolation `#{...}` whose expression reads one of
      # `Fields` (`x[:snippet]`, `x["description"]`, `x.snippet`,
      # `x.dig(:a, :posts)`) or, without a receiver, one of `BareFields` (the
      # context keys `news_content`, `snippets`, `posts`), unless the read sits
      # inside an `xml_wrap_untrusted` or `escape_xml` call, or the whole
      # string is an argument to one. Bare names are a shorter list because a
      # prompt's own helper may well be called `content` or `text`.
      #
      # @example
      #   # bad
      #   "- Snippet: #{result[:snippet]}"
      #
      #   # good
      #   xml_wrap_untrusted("snippet", result[:snippet])
      #   "- Snippet: #{escape_xml(result[:snippet].to_s)}"
      #
      class PromptUntrustedTextWrapped < Base
        MSG = "`%<source>s` is third-party text interpolated without `xml_wrap_untrusted`. " \
              "Wrap it, and keep ThirdPartyText::RULE in the system prompt."

        DEFAULT_FIELDS = %w[
          snippet snippets description text content body bio summary news_content post posts
        ].freeze
        DEFAULT_BARE_FIELDS = %w[news_content snippets posts].freeze
        SAFE_CALLS = %i[xml_wrap_untrusted escape_xml escape_xml_attribute].freeze

        def on_dstr(node)
          return if wrapped?(node)

          node.each_child_node(:begin) do |interpolation|
            read = interpolation.each_node(:send, :csend).find do |candidate|
              third_party_read?(candidate) && !wrapped?(candidate, stop: interpolation)
            end
            add_offense(read, message: format(MSG, source: read.source)) if read
          end
        end

        private

        def third_party_read?(node)
          if node.method?(:[]) || node.method?(:dig) || node.method?(:fetch)
            key_args = node.method?(:fetch) ? [node.first_argument] : node.arguments
            key_args.compact.any? { |arg| arg.type?(:sym, :str) && fields.include?(arg.value.to_s) }
          elsif node.arguments?
            false
          else
            (node.receiver ? fields : bare_fields).include?(node.method_name.to_s)
          end
        end

        # Inside an escaping call, looking no further up than `stop`.
        def wrapped?(node, stop: nil)
          node.each_ancestor do |ancestor|
            return false if stop && ancestor.equal?(stop)
            return true if ancestor.type?(:send, :csend) && SAFE_CALLS.include?(ancestor.method_name)
          end
          false
        end

        def fields
          @fields ||= Array(cop_config.fetch("Fields", DEFAULT_FIELDS)).map(&:to_s)
        end

        def bare_fields
          @bare_fields ||= Array(cop_config.fetch("BareFields", DEFAULT_BARE_FIELDS)).map(&:to_s)
        end
      end
    end
  end
end
