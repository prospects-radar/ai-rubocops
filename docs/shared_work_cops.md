# The SharedWork cops

Three cops that keep a shared work list inside its purpose, and a plain account of
what each one cannot see.

## Why they exist

ProspectsRadar shows a list of opportunities nobody has picked up. ADR-0063 decided
what a row of that list may say about the colleague holding the work: that it is
held, and nothing further. ADR-0087 then withdrew the role that guarded the page,
because a backlog the whole team reads is collaboration, while the same backlog
visible only to the person who rates you is supervision — and WP249 §6.4 is about
the asymmetric case.

Withdrawing the role leaves three properties as the only thing keeping the list
inside its purpose:

1. no colleague's name on a shared work row,
2. no aggregation per person,
3. no usage behaviour as an input.

#1107 pins those to the rendered page as request specs. These cops pin them to the
code. The specs answer "does the page do this today"; the cops answer "is somebody
adding it right now", which is the cheaper moment to find out.

**The cops do not replace the specs.** A cop reads one file at a time and sees no
intent. Both layers stay.

## Scope is a declaration, not a detection

There is no way to recognise "a shared work list" from source. The `Include` list
under `SharedWork/*` in `.rubocop.yml` is therefore the definition, and a new list
built somewhere else is outside these cops until its path is added there and in the
`shared_work_boundary` sensor in `config/sidecar.rb`. Adding it is part of building
one.

Two files are deliberately out of scope:

- `app/jobs/unattended_opportunities_digest_job.rb` picks recipients, so it reads an
  address per person by design. What it mails comes from the service and the mailer
  component, and both are in scope.
- `app/services/home_service.rb` counts what is new since the reader last looked,
  from the reader's own `ProspectView` rows. That is somebody about themselves.

## The escape hatch

Every cop here accepts a comment naming the decision that allows the exception, on
the offending line or the line directly above it:

```ruby
# shared-work-allowed: ADR-0087 — the assignment control names who it assigns to
task.assigned_to.full_name
```

`ADR-0087` or `#1101` both count. One line further away and it stops counting: a
reason that has drifted from the code it excuses is a reason nobody will move when
the code moves. A bare `rubocop:disable` silences these cops as it silences any cop
— it just records nothing about who decided what.

## SharedWork/NoPersonNameInWorkList

Flags a name-ish method (`name`, `full_name`, `email`, `initials`, …) called on a
colleague-ish receiver (`assigned_to`, `assignee`, `created_by`, `owner`, `user`, …).

**What it does not see:**

- a name that arrives already rendered — a presenter method, a serializer, an I18n
  interpolation fed from elsewhere;
- a column that happens to hold a person's name (`last_editor_label`,
  `signature_line`);
- `current_user`, left alone on purpose: the reader's own name in a greeting or a
  menu says nothing about anybody else. #1107 hit exactly that and had to narrow its
  own assertion.

## SharedWork/NoPersonAggregation

Flags `group`, `group_by`, `order`, `reorder`, `sort`, `sort_by`, `tally`, `count`,
`index_by` and `partition` keyed on a person column or method, including through a
block body: `sort_by { |task| task.assigned_to.name }` is the same mistake as
`group_by(&:assigned_to_id)`.

**What it does not see:**

- an aggregation done in SQL the cop cannot parse — a `find_by_sql`, a raw
  `Arel.sql` fragment, a database view;
- a per-person number computed one row at a time and assembled later;
- a proxy for a person that is not named like one: a team id, a mailbox, a desk;
- `pluck(:assigned_to_id)` and `includes(:assigned_to)`, which are deliberately
  accepted. Naming the column is not reporting on it.

## SharedWork/NoProspectViewRead

Flags any mention of `ProspectView` in a file in scope. Blunt on purpose: no reading
of a view record is something this list needs, so there is no shape worth
distinguishing. ADR-0082 has the second reason — a glance never expired, so one
click used to retire a prospect from the list for the rest of its life.

**What it does not see:**

- the same data under another name: a `last_seen_at` column, a view count
  denormalised onto the prospect, an analytics table with a different class;
- behaviour arriving through a service that reads it elsewhere and hands over a
  number.

## What no cop here will ever catch

A new column that measures productivity by another name. A score that happens to
resolve to one person. A filter that leaves exactly one colleague's work on screen.
Those are questions about intent, and they belong to the checklist in ADR-0087 and
to the factsheet from #1108.

A gate that promises more than it delivers is worse than no gate. This one covers
the shapes above, on the paths listed in `.rubocop.yml`, and nothing else.
