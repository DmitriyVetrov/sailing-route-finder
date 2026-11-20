# sailing-route-finder

Ruby CLI, stdin/stdout, must build and run in Docker (Docker is the only tool that
may be assumed installed). Features: cheapest-direct, cheapest, fastest and saved
searches. Focus on OO design, SOLID, DRY and test coverage.

## Files

- `README.md` — build/run/test instructions and the problem statement. **The only source
  of truth for requirements.**
- `docs/PLAN.md` — the implementation plan, built in nine phases.
- `docs/NOTES.md` — every assumption and decision, for the reviewer.
- `data/response.json` — the sample rates feed. Never edited; synthetic cases go in
  `spec/fixtures/` or are built inside the specs.

## Decisions in force

Decisions confirmed by the PO are marked *Confirmed*.

- **fastest** = first departure to final arrival, layovers included. *Confirmed*
  ("the waiting time counts").
- **duplicate rates** for one `sailing_code` (the feed has `MNOP` twice) → take the
  **highest**, behind a replaceable resolver. *Confirmed* ("intentional, use the higher
  one"). On `response.json` this makes cheapest-direct CNSHA→NLRTM `ABCD` 589.30 USD.
- **saved searches** → our own call ("no right or wrong answer"). Chosen: file-based waiting
  list + an inotify watcher on the feed + a notifications directory.
- Exchange rates are EUR-based; the rate for a sailing is picked by its
  `departure_date` (stated in the README).
- **Dirty feed data** never reaches the user: a broken document is an empty feed, a dirty
  record is dropped, and both are written to `data/logs/route_finder.log`.
- **README inconsistencies** — the example's `"rate": "123.00"` vs cheapest-direct's
  `"232.30"` is read as a placeholder; fastest's output being identical to
  cheapest's is read as a copy-paste. Our own documented assumptions.

Document every assumption in `docs/NOTES.md`.

## Code conventions

- Readability over idiom: explicit `return`, explicit `if/else`, named locals for
  intermediate steps, no clever one-liners.
- Plain classes with `attr_reader` and `initialize`; no `Struct`, `OpenStruct` or
  `Data.define`; no metaprogramming or monkey patching.
- Dependencies are injected through constructors; `RouteFinder::Application` is the only
  place that wires objects together, and only `bin/` touches the process (streams, ENV,
  exit codes).
- Comments in English and minimal: a 1–2 line header per file, one line on key methods,
  architecture and logic only.
- `bundle exec rspec` must stay at 100% line and branch coverage of `lib/`.
