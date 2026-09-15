# frozen_string_literal: true

module RuboCop
  module Cop
    module Architecture
      # Flags a `LIKE` against a company's `website` or `domain` whose result is
      # immediately reduced to ONE record. That combination is a substring
      # pretending to be an identity test, and it has been wrong three times.
      #
      # `#926` measured it on this table: `website LIKE '%https%'` put 2629 of
      # 2841 companies behind one "domain" and `.first` picked one of them, so
      # tenders from four countries bound to a single account's own customer
      # company. `#934` removed two copies from the enrichment agents. `#1055`
      # removed the third from `Company.find_prospect_company_by_domain`, where
      # `arval.nl` matched a stored `notarval.nl`, an `arval.nl.partnersite.com`,
      # and any URL that merely mentioned the host in a path or query — and where
      # the winner, unordered, was whatever the planner returned that day.
      #
      # A host has to match at its boundaries or it says nothing about who owns
      # the site. `Companies::IdentityMatcher::WEBSITE_HOST` extracts the host in
      # SQL and compares it, `HostName.identity?` refuses a value that is not
      # shaped like a registrable domain, and ties break on `order(:id)`. Reach
      # all three through `Companies::ResolveCompany`.
      #
      # Deliberately silent on a LIKE whose result stays a relation. A search
      # filter ("companies whose website contains what the user typed") returns a
      # list for somebody to choose from and is a legitimate substring use; it is
      # picking ONE row out of a substring match that decides an identity by
      # accident. `name ILIKE` never fires — a name is not a hard key.
      #
      # @example
      #   # bad — a substring, reduced to one row, deciding which company this is
      #   Company.where("LOWER(companies.website) LIKE ?", "%#{domain}%").first
      #   Company.where("website ILIKE ANY (ARRAY[?])", patterns).first
      #   Company.find_by("domain LIKE ?", "%#{domain}%")
      #
      #   # good — the resolver every other path already goes through
      #   Companies::ResolveCompany.call(identity: { domain: host }, scope: Company.all)
      #
      #   # good — a search filter, left as a relation for the caller to page
      #   scope = scope.where("LOWER(website) LIKE ?", "%#{query}%")
      class NoSubstringIdentityMatch < Base
        MSG = "A `LIKE` on `%<column>s` picked down to one row is a substring, not an identity test " \
              "(#926, #934, #1055). Resolve through `Companies::ResolveCompany` — it matches the host at " \
              "its boundaries and breaks ties with `order(:id)`."

        # The columns that are hard identity keys. A name is not one of them.
        DEFAULT_IDENTITY_COLUMNS = %w[website domain].freeze

        # Methods that turn a relation into at most one record. `find_by` also
        # appears as the query method itself, which is why it is matched below.
        SINGLE_RECORD = %i[first last take first! last! take! find_by find_by! sole].to_set.freeze

        # Query methods that accept a raw SQL fragment as their first argument.
        QUERY_METHODS = %i[where having find_by find_by! not].to_set.freeze

        # Chain links that keep a relation a relation, so `.order(:id).first`
        # still reads as picking one row.
        RELATION_LINKS = %i[
          order reorder limit offset includes preload eager_load joins left_joins
          where having not references distinct unscope readonly select merge
        ].to_set.freeze

        def on_send(node)
          return unless QUERY_METHODS.include?(node.method_name)

          column = identity_column_liked(node)
          return unless column
          return unless single_record?(node)

          add_offense(node.loc.selector, message: format(MSG, column: column))
        end
        alias on_csend on_send

        private

        # The identity column a SQL-fragment argument runs a LIKE against, or nil.
        # Reads dstr as well as str: the fragment is often interpolated.
        def identity_column_liked(node)
          fragment = node.arguments.first
          return nil unless fragment&.type?(:str, :dstr)

          source = fragment.source
          identity_columns.find { |column| source.match?(like_pattern(column)) }
        end

        # `website LIKE`, `LOWER(companies.website) LIKE`, `website ILIKE ANY (…)`.
        # The column may be qualified and may sit inside a function call, so allow
        # a closing paren between it and the operator.
        def like_pattern(column)
          /(?<![a-z_])#{Regexp.escape(column)}\s*\)*\s+(?:NOT\s+)?I?LIKE(?![a-z_])/i
        end

        # True when this query's result is at most one record: either the query
        # method is itself a finder, or the chain hanging off it ends in one
        # before anything else consumes the relation.
        def single_record?(node)
          return true if node.method_name.to_s.start_with?("find_by")

          current = node
          while (parent = current.parent) && parent.type?(:send, :csend) && parent.receiver == current
            return true if SINGLE_RECORD.include?(parent.method_name)
            return false unless RELATION_LINKS.include?(parent.method_name)

            current = parent
          end

          false
        end

        def identity_columns
          @identity_columns ||= begin
            configured = Array(cop_config["IdentityColumns"]).map(&:to_s)
            configured.empty? ? DEFAULT_IDENTITY_COLUMNS : configured
          end
        end
      end
    end
  end
end
