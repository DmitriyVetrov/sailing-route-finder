# Implementation plan — 9 phases

The solution is built in nine phases. Each phase is run in its **own fresh session**,
produces working code, ends in one git commit, and leaves the repository in a state
that can be built and executed. Each phase depends on the one before it.

Every phase prompt below is ready to paste as the first message of a new session.
Rules from `CLAUDE.md` apply throughout and are not repeated in the prompts.

Target architecture (decided before this plan, do not redesign): time-expanded event
graph + generic Dijkstra over an abstract `Weight`, with every documented point of
ambiguity isolated behind a replaceable policy object.

| phase | theme | tickets | result you can run |
|---|---|---|---|
| 1 | walking skeleton in Docker | — | `docker run` echoes a hardcoded JSON answer |
| 2 | feed → domain objects, money | — | prints the real EUR cost table for all 9 sailings |
| 3 | cheapest-direct, end to end | cheapest-direct | first real answer from real data |
| 4 | generic Dijkstra on a toy graph | — | textbook graph solved, zero domain knowledge |
| 5 | time-expanded graph builder | — | dumps the event graph for `response.json` |
| 6 | cheapest (indirect) | cheapest | 322.89 EUR via ERXQ+ETRG |
| 7 | fastest | fastest | new criterion added by 1 class + 1 registry line |
| 8 | waiting list + notifications | saved searches | unfulfillable search waits in `data/waiting_list/`; the watcher moves it to `data/notifications/` once the feed can serve it |
| 9 | hardening + submission | — | coverage, notes, English comments, zip |

Phases 1–3 deliberately contain no graph and no Dijkstra: the first ticket does not
need them, and a working vertical slice is worth more than a clever core with no CLI
around it. The graph appears only in phases 4–5, split so that the algorithm and the
graph are each understood in isolation before they meet in phase 6.

---

## How each phase is run — two stages, with a stop in between

Every phase is executed as a **fresh session** and in **two stages**, so the plan for a
phase is reviewed before any code is written.

### Stage 1 — explain, then stop

Read the files the phase needs (`CLAUDE.md`, `docs/PLAN.md`, the phase's source files,
the feed) and **write nothing**: no new files, no edits, no commits. The deliverable is
an explanation covering:

1. **Which files appear and which change**, each with one sentence on what it is for.
2. **Why this phase exists at this point** — what it makes possible that was not
   possible before, and what it deliberately leaves out.
3. **Which new language constructs show up**, and why each is the plainest choice.
4. **How the result will be verified** — the exact commands from the phase's "Done
   when" block and what their output should be.
5. **Any decision the phase leaves open**, stated as a question with a recommended
   answer, so it can be settled before coding rather than after.

### Stage 2 — implement, on the go-ahead

Implementation starts only on an explicit go-ahead; a question or a requested change
is not one. Then follow the phase's own prompt block below. Anything outside the
phase's scope is named as belonging to a later phase rather than pulled forward.

---

## Phase 1 — Walking skeleton in Docker

**Goal:** a runnable Ruby CLI in a container, with a test suite, and nothing else.
No domain logic at all — the answer is hardcoded.

**Creates:** `Dockerfile`, `.dockerignore`, `Gemfile`, `Gemfile.lock`, `.gitignore`,
`bin/route_finder`, `lib/route_finder.rb`, `lib/route_finder/cli.rb`,
`spec/spec_helper.rb`, `spec/route_finder/cli_spec.rb`.

**Scope:** `CLI` reads exactly three lines from stdin (origin, destination, criteria),
validates that the criteria string is one of the three known values, and prints a
hardcoded one-leg JSON array. Unknown criteria exits non-zero with a message on stderr.

**Ruby introduced:** `module`/`class`, `require_relative`, `initialize` + `attr_reader`,
`$stdin`/`$stdout` injected as constructor arguments (so tests use `StringIO`),
string methods, `JSON.pretty_generate`, RSpec `describe`/`it`/`expect`.

**Done when:**
```
docker build -t sailing-route-finder .
printf 'CNSHA\nNLRTM\ncheapest-direct\n' | docker run -i --rm sailing-route-finder
docker run --rm sailing-route-finder bundle exec rspec
```
print valid JSON and a green suite.

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 1** exactly as its
> section specifies, and nothing beyond it. Ruby 3.3 on a slim base image, RSpec as
> the only dependency. Inject stdin/stdout into `CLI` as constructor arguments so the
> specs can drive it with `StringIO`. At the end, run the two Docker commands from the
> phase's "Done when" block, show me the real output, then commit on `main`. Before
> you write code, explain what each file will be for.

---

## Phase 2 — Feed, domain objects, money

**Goal:** turn `response.json` into typed objects and compute every sailing's cost in
EUR. Still no graph, no search, no CLI change.

**Creates:** `lib/route_finder/money.rb`, `lib/route_finder/feed/sailing.rb`,
`lib/route_finder/feed/loader.rb`, `lib/route_finder/feed/exchange_rates.rb`,
`lib/route_finder/feed/rate_book.rb`,
`lib/route_finder/feed/rate_resolvers/highest_rate.rb`, plus specs for each, plus
`bin/cost_table` (a throwaway debug script that prints the table).

**Scope:** `Money` holds an amount as `BigDecimal` plus a currency and never mixes
currencies silently. `Sailing` is a value object (ports, dates, code, `duration_days`).
`ExchangeRates` answers "EUR rate for this currency on this date" and raises a clear
error when the date or currency is missing. `RateBook` maps `sailing_code` to a
`Money`, resolving duplicates through an injected resolver; `HighestRate` is the only
resolver for now (the higher rate wins — confirmed by the PO, see `CLAUDE.md`). **The original rate string and currency must be preserved** on the
sailing — the output format echoes them verbatim, EUR is only ever an internal
comparison currency.

**Ruby introduced:** `BigDecimal`, `Date.iso8601` and date subtraction, `Hash#fetch` with
and without a default, raising custom error classes, `Comparable` with `<=>`,
`freeze`, grouping a list into a hash.

**Done when:** `docker run --rm sailing-route-finder bin/cost_table` reproduces this
table, which is already verified and must be asserted in specs:

| code | route | dep → arr | days | EUR |
|---|---|---|---|---|
| ABCD | CNSHA→NLRTM | 02-01 → 03-01 | 28 | 523.36 |
| EFGH | CNSHA→NLRTM | 02-02 → 03-02 | 28 | 890.32 |
| IJKL | CNSHA→NLRTM | 01-31 → 02-28 | 28 | 742.78 |
| MNOP | CNSHA→NLRTM | 01-30 → 03-05 | 34 | 729.04 |
| QRST | CNSHA→NLRTM | 01-29 → 02-15 | 17 | 761.96 |
| ERXQ | CNSHA→ESBCN | 01-29 → 02-12 | 14 | 261.96 |
| ETRF | ESBCN→NLRTM | 02-15 → 03-29 | 42 | 61.80 |
| ETRG | ESBCN→NLRTM | 02-16 → 02-20 | 4 | 60.93 |
| ETRB | ESBCN→BRSSZ | 02-16 → 03-14 | 26 | 383.17 |

(`MNOP` appears twice in the feed, at 456.78 and 812.00 USD; 729.04 EUR is the higher
one, resolved by `HighestRate`. The lower one would be 410.11 EUR. A spec must cover
that duplicate explicitly.)

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 2** exactly as its
> section specifies. Do not touch the CLI or add any graph/search code. Rounding:
> compare in `BigDecimal`, round only for display. Every class gets its own spec, and
> the EUR table in the phase section becomes a spec that reads the real
> `response.json`. Explain, before coding, why `Money` and `Sailing` are
> separate objects and why the original rate string must survive into the output.
> Finish by running `bin/cost_table` and the suite in Docker, then commit.

---

## Phase 3 — cheapest-direct, cheapest-direct end to end

**Goal:** the first ticket, fully wired: real input, real feed, real answer. This
proves the vertical slice before any graph exists.

**Creates:** `lib/route_finder/presenter/legs_presenter.rb`,
`lib/route_finder/criteria/cheapest_direct.rb`,
`lib/route_finder/criteria_factory.rb`, specs for each. Modifies `cli.rb` to use
the factory. Deletes the hardcoded answer from phase 1.

**Scope:** `CheapestDirect` filters sailings to the exact origin/destination pair and
returns the one with the lowest EUR cost. `LegsPresenter` renders a list of sailings
as the JSON array from the README, echoing the original `rate` and `rate_currency`.
`CriteriaFactory` is a frozen hash from criteria string to criteria class, looked
up with `fetch` — no `case`. Empty result prints `[]` for now (phase 8 replaces that).

**Ruby introduced:** selecting and sorting a collection, `min_by`, a frozen
hash constant as a registry, `fetch` raising `KeyError`, dependency injection through
keyword arguments.

**Done when:**
```
printf 'CNSHA\nNLRTM\ncheapest-direct\n' | docker run -i --rm \
  -v "$PWD/response.json:/app/response.json" sailing-route-finder
```
returns the single `ABCD` leg with `"rate": "589.30"` and `"rate_currency": "USD"`
(523.36 EUR). With the higher duplicate rate in force, `MNOP` costs 729.04 EUR and
no longer wins; under a lowest-rate policy it would (456.78 USD, 410.11 EUR).

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 3** exactly as its
> section specifies. `cheapest-direct` must NOT use a graph or Dijkstra — it is a
> filter plus a minimum, deliberately. Decide and document how the feed path reaches
> the app (argument, env var or fixed path) and explain the choice. The
> registry in `CriteriaFactory` must make "add a criterion" mean "add a class and
> one line", with no `case` anywhere in the core. Run the "Done when" command, show
> the real output, then commit.

---

## Phase 4 — Generic Dijkstra on a toy graph

**Goal:** the algorithm, in isolation, knowing nothing about ports, money or dates.
No sailing touches this phase.

**Creates:** `lib/route_finder/weights/` (`money_weight.rb`, `duration_weight.rb`),
`lib/route_finder/shortest_path/dijkstra.rb`, `lib/route_finder/shortest_path/path.rb`,
`spec/support/toy_graph.rb`, specs including a contract spec for the `Weight` protocol.

**Scope:** `Dijkstra` depends on exactly two collaborators: something answering
`edges_from(node)` and something answering `weight_of(edge)`. A `Weight` must provide
`+` and `<=>` and nothing more. Lazy-deletion priority queue (push a new entry instead
of decrease-key, skip stale pops), `prev` map, path reconstruction. Determinism lives
inside the weight type as extra comparison components, not as special-casing in the
algorithm.

**Done when:** specs solve the textbook graph already used in discussion — A→B 4,
A→C 2, C→B 1, B→D 5, C→D 8, C→E 10, D→E 2, D→F 6, E→F 3 — and assert
`A→C→B→D→E→F` at cost 13, with the per-step distances `A0 C2 B3 D8 E10 F13`. Plus a
property-style spec asserting the monotonicity contract (`a <= b` implies
`a + c <= b + c`) for both weight types.

**Ruby introduced:** operator methods (`def +`), `include Comparable`, `Array#<=>` for
lexicographic comparison, a minimal priority queue (plain sorted array or a hand-rolled
heap — pick the readable one and say why), `Set`, test doubles for the two collaborators.

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 4** exactly as its
> section specifies. `Dijkstra` must not reference any sailing, port, date or currency
> type — specs use a toy graph and fake weights only. Explain, before
> coding: why `Weight` needs only `+` and `<=>`, why the monotonicity contract matters
> (what breaks silently without it), and why tie-breaking belongs in the weight type
> rather than in the search loop. Also leave a comment at the top of `dijkstra.rb`
> stating the non-negativity precondition. Run the suite in Docker, then commit.

---

## Phase 5 — Time-expanded graph builder

**Goal:** turn the sailings into the event graph, and be able to look at it. Still no
search.

**Creates:** `lib/route_finder/graph/node.rb`, `lib/route_finder/graph/edge.rb`,
`lib/route_finder/graph/time_expanded_graph.rb`, specs, and `bin/dump_graph`
(a debug script printing nodes and edges grouped by port; takes origin and
destination, default `CNSHA NLRTM`). **Modifies (phase 2 code):**
`lib/route_finder/feed/loader.rb` and its spec — rejects a sailing whose
`arrival_date` is not strictly after its `departure_date`, with an error from
`errors.rb`.

**Scope:** a node is `(port, date)`, a frozen value object usable as a hash key; a
sailing edge goes from `(origin, departure)` to `(destination, arrival)`; waiting
edges chain consecutive events inside one port (every port, destination included),
forward in time only. One `Edge` class: `sailing` is `nil` on a waiting edge, plus a
`waiting?` predicate.

Transfer rule: same-day transfer is allowed (`departure >= arrival`) — an assumption
to be documented. There is **no `TransferPolicy` object**: with `(port, date)` nodes and
waiting edges between consecutive events, the same-day rule always holds by
construction, so such an object would never return `false`. A stricter rule (minimum
connection time) cannot be expressed in this model — an arrival and a stay on the same
date share one node — and would need `(port, date, kind)` nodes with an
arrival→earliest-allowed-departure transfer edge. This is documented as the extension
point, not built.

Query endpoints: `TimeExpandedGraph` takes the origin and destination ports in its
constructor and is rebuilt per query; it adds a super-source into every event at the
origin port and a super-sink out of every event at the destination port. Accepted
trade-off: feed data and query are mixed in one object, in exchange for simplicity.

**Done when:** `bin/dump_graph` prints the event graph for `response.json`, and specs
assert: the `ERXQ (ESBCN, 02-12) → wait → (ESBCN, 02-16) → ETRG` chain exists; no edge
ever goes backwards in time; the graph is acyclic; super-source and super-sink are
wired to the right ports; `Loader` rejects a sailing with `arrival_date <=
departure_date`.

**Ruby introduced:** using a value object as a hash key (`hash`/`eql?`/`==`, and why
`Comparable` is not enough),
sorting dates, building a hash of arrays, nested iteration over consecutive pairs
(`each_cons`).

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 5** exactly as its
> section specifies. No search in this phase. The time constraint must be expressed by
> which edges exist, never by a check inside a future search loop — explain
> why that distinction is the whole point of this design. Implement `hash`/`eql?` on
> the node object. Run
> `bin/dump_graph` in Docker, paste the output, then commit.

---

## Phase 6 — cheapest, cheapest (direct or indirect)

**Goal:** the first phase where graph and algorithm meet. Second ticket done.

**Creates:** `lib/route_finder/criteria/cheapest.rb`, specs. Modifies the factory
registry and, if needed, `LegsPresenter` for multi-leg output.

**Scope:** `Cheapest` builds the time-expanded graph, weights sailing edges with the
EUR cost and waiting edges with zero, runs `Dijkstra`, and maps the resulting node
path back to the list of sailings it used. Must handle more than two legs (README
requirement 6) — covered by a synthetic three-leg fixture, since the sample feed has
no such route.

**Done when:**
```
printf 'CNSHA\nNLRTM\ncheapest\n' | docker run -i --rm \
  -v "$PWD/response.json:/app/response.json" sailing-route-finder
```
returns the two legs `ERXQ` then `ETRG` (261.96 EUR + 60.93 EUR = 322.89 EUR, beating
the best direct option `ABCD` at 523.36 EUR), the same legs as the README's expected
output. The `arrival_date` of `ERXQ` comes from the feed (2022-02-12), not from the
README's printed 2022-02-06. A separate spec covers a three-leg route on a synthetic feed.

**Ruby introduced:** mapping a node path back to domain objects, keeping the mapping
explicit rather than clever.

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 6** exactly as its
> section specifies. Reuse `Dijkstra` and `TimeExpandedGraph` without modifying
> either; if you find you need to change them, stop and tell me why instead. Add a
> synthetic three-leg fixture under `spec/fixtures/` for the multi-leg requirement.
> Explain, before coding, why a naive port-vertex Dijkstra with a
> `(cost, arrival)` label would be wrong here — use a concrete counterexample. Run the
> "Done when" command, show the output, then commit.

---

## Phase 7 — fastest, fastest

**Goal:** deliberately small. The point of this phase is to feel that a new criterion
costs one class and one registry line, with zero changes to the graph, the algorithm
or the CLI. Third ticket done.

**Creates:** `lib/route_finder/criteria/fastest.rb`, specs. Modifies only the registry.

**Scope:** `Fastest` reuses the same graph with `DurationWeight`: sailing edges weigh
`arrival - departure`, waiting edges weigh the layover. The path total then equals
`final arrival - first departure`, which is exactly the assumption in force. The
alternative definition (sum of sailing time only, layovers excluded) must be reachable
by changing the waiting-edge weight to zero and nothing else — leave a comment saying so.

**Done when:** `fastest` for CNSHA→NLRTM returns the direct `QRST` leg, 17 days. A
spec documents in its description **why this disagrees with the README's printed
expectation** (README shows ERXQ+ETRG and an ERXQ arrival of 2022-02-06, while the
feed says 2022-02-12; on feed data ERXQ+ETRG is 22 days, or 18 with layovers excluded,
against QRST's 17 — so QRST wins under both readings). Do not "fix" the feed to match the README.

**Ruby introduced:** none required — that is the point. Note in the commit message how few
files changed.

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 7** exactly as its
> section specifies. You should need to add one criteria class and one registry line
> and change nothing else — if that is not true, stop and explain what the previous
> phases got wrong. The `fastest` answer for the sample feed is the direct QRST at 17
> days, which contradicts the README's printed expectation; encode the real answer and
> document the contradiction in the spec description, do not alter the feed. Report how many files the phase touched and why that number is the architectural
> payoff. Then commit.

---

## Phase 8 — saved searches, waiting list and notifications

**Goal:** the fourth ticket ("save a search now, fulfil it later"). A search that finds
no route goes to the waiting list; when the feed changes, every waiting request is
re-run, and those that now have a route move to notifications. Route finding is
reused as-is, not modified. Vocabulary: the README calls the entity a "saved search";
this project calls it a waiting request and uses "waiting list" throughout.

**Flow (agreed with the owner, 2026-10-18):**
1. The CLI gets an empty result for the requested criteria → prints `[]` to stdout, a
   note to stderr, exits 0, and saves the request as
   `data/waiting_list/<ORIGIN>_<DEST>_<criteria>.json`, whose content is the request
   itself: `{"origin_port", "destination_port", "criteria"}`. No date or GUID in the
   name: repeating the same search overwrites the same file. All three parts of the
   name (both ports and the criteria) are validated to `[A-Za-z0-9-]` before they
   become part of a path — the dash is needed for `cheapest-direct`; anything else
   raises `InvalidSearchRequestError` (a `RouteFinder::Error`, so the CLI prints one
   line to stderr, nothing to stdout, and exits 1) and nothing is saved. Saving happens
   before printing for exactly that reason. An unknown criteria is an error and is not
   saved. The
   three-argument mode (VS Code) behaves identically.
2. The feed changes → `bin/watch_feed` runs `bin/process_waiting_list`, which loads
   the feed and calls `WaitingList#process`: every waiting request is re-run with its
   own criteria — in-process, through the same `CriteriaFactory` and `LegsPresenter`
   the CLI uses (no shelling out to the CLI).
3. A request now has a route → its file **moves** to `data/notifications/` under the
   same name, and its content becomes exactly the README output format (the JSON the
   CLI would print). Order: write the result to a temp file in `notifications/`,
   `rename` it into place, then delete the waiting-list file — a crash in between
   reprocesses the request but never loses it.
4. When the CLI does find a route, it does not touch the waiting list (the CLI only
   ever calls `save`).

**Change detection — inotify:** `bin/watch_feed` is a shell script (no extension, as
every entry point in `bin/`; the shebang picks the interpreter) and the container's
main process. On start it runs one pass (the feed may have changed while the
container was down), then `inotifywait -m` listens on the **directory** `data/` for
`close_write` and `moved_to`, and runs a pass for every event on `response.json`. The
directory is watched, not the file, because replacing a file (`mv`, editors) creates
a new inode the old watch would not follow. Chosen because the files live inside the
Linux container, where kernel events are reliable: instant, fired only after the
writer closes the file, and no Ruby loop to write. Polling was rejected — it was only
needed for files changed on a Mac/Windows host. The Dockerfile installs
`inotify-tools`.

**Failure handling:** a feed that does not parse (`JSON::ParserError`) or holds invalid
data (`RouteFinder::Error`) is not handled specially: Ruby prints the uncaught
exception to stderr and exits 1. The feed is loaded before any request file is
touched, so the waiting list is left as it was, and the shell loop keeps waiting for
the next event. A single corrupt request file is caught by a few lines of `rescue`,
reported on stderr and skipped; the others are still processed.

**Minimal footprint (owner's decision, 2026-10-19):** as few new files and as few
edits to existing ones as possible. Four new files, small edits elsewhere.

**Creates:**
- `lib/route_finder/waiting_list.rb` — one class `WaitingList(waiting_dir,
  notifications_dir)` with two public methods: `save(origin, destination, criteria)`
  (validation, file name, request written as a plain hash; returns the file name) and
  `process(factory, presenter, error_output)` (one pass over the waiting list; reads
  the waiting files itself, reports skipped corrupt files to `error_output`, returns
  the names it fulfilled). Private: `fulfil` (atomic move into `notifications/`) and
  the temp-file-plus-`rename` write. `InvalidSearchRequestError` is declared in this
  file rather than in `errors.rb`, because only this class raises it.
- `bin/process_waiting_list` (Ruby, one pass) and `bin/watch_feed` (shell, inotify).
- `spec/route_finder/waiting_list_spec.rb` — runs against temporary directories
  (`Dir.mktmpdir`) and the real sample feed; no new fixture.

**Edits:**
- `lib/route_finder.rb`: one `require_relative`.
- `lib/route_finder/cli.rb`: a `waiting_list:` constructor argument; on an empty
  result, `save` plus the stderr note. A deliberate change to phase-3 code.
- `bin/route_finder`: the feed path, plus building the `WaitingList` for the CLI.
- `spec/route_finder/cli_spec.rb`: `waiting_list:` (a test double) added to the two
  existing `CLI.new` calls, plus a `waiting list` group: empty result → saved, the
  stderr note with stdout still plain `[]`, a found route → not saved, a failed save →
  nothing on stdout and exit 1. The existing "no direct sailing" test no longer
  expects an empty stderr — a deliberate change of phase-3 behaviour.
- `Dockerfile`: one `RUN apt-get install inotify-tools` in the final stage; `CMD`
  unchanged.
- `.gitignore`, `.dockerignore`: `data/waiting_list/` and `data/notifications/`, so
  local runs do not end up in git or in the image.
- `bin/cost_table`, `bin/dump_graph`, `spec/support/feed_helpers.rb`: the feed path
  only (forced by the move).
- `.vscode/launch.json`: a configuration for `bin/process_waiting_list`.

**Deliberately not created** (each is an obvious later cut, no behaviour change): no
`SearchRequest` class (the request is a plain hash, and its file name and validation
live in `WaitingList`, the only place that needs them); no separate `Notifier` or
`Fulfiller` (storage, move and pass share one class); no application builder (the
four wiring lines are repeated in `bin/process_waiting_list`); no contract specs or
in-memory doubles; no new ENV variables.

**Data layout:** `response.json` lives at `data/response.json` (moved with `git mv`).
The waiting-list and notifications directories are derived from the feed path —
`File.dirname(feed_path)` + `waiting_list` / `notifications` — so the existing
`FEED_PATH` is the only setting. Directories are created on first write
(`FileUtils.mkdir_p`). Data lives in the container's own filesystem, no volume: it
survives `docker stop` / `docker start` and restarts after a crash, and is gone after
`docker rm`. The Done-when commands of phases 3 and 6 refer to the old feed path and
are left as history.

**Docker:** plain Docker only, no Compose. One image, two roles. `CMD` stays
`["bin/route_finder"]`, so the phase-3 command still runs a search:
```
printf 'CNSHA\nNLRTM\ncheapest-direct\n' | docker run -i --rm sailing-route-finder
```
The waiting-list service is the same image with an explicit command, whose main
process is `bin/watch_feed`:
```
docker build -t sailing-route-finder .
docker run -d --name app --init --restart unless-stopped sailing-route-finder bin/watch_feed
docker exec -it app bin/route_finder
docker cp new_feed.json app:/app/data/response.json
docker exec app ls data/waiting_list data/notifications
docker logs app
docker stop app && docker rm app
```
`--restart unless-stopped` brings the same container (same files) back after a crash;
`--init` puts a minimal init in front of the shell script so `docker stop` is
delivered at once instead of after the 10-second timeout. Tests:
`docker run --rm sailing-route-finder bundle exec rspec`. Verified in the demo: inotify
does fire on `docker cp`, so it is the documented way to replace the feed;
`cat new_feed.json | docker exec -i app sh -c 'cat > data/response.json'` is an
alternative (writes from inside the container, so `close_write` fires; not demoed).

**SOLID — including what minimalism costs:** the trigger
(`bin/watch_feed`), the dialogue (`CLI`), route finding (`CriteriaFactory`) and the
waiting list are separate; changing how the feed change is detected touches only the
shell script, and a new criterion works for the waiting list with no change. The CLI
receives `WaitingList` through its constructor and calls only `save` (D, I); Ruby has
no `interface` keyword, so anything answering `save` can stand in — the CLI spec uses
a test double. The accepted cost: `WaitingList` holds storage, delivery and the pass
in one class, so a webhook or SQLite means editing it rather than adding a class
(S and O are traded for size). The cut lines are
`fulfil` → a `Notifier`, `process` → a `Fulfiller`, without changing behaviour.

**Out of scope for v1 (documented as assumptions):**
- notification life cycle (read, dismissed) and delivery beyond writing the file;
- a re-saved and re-fulfilled request overwrites the earlier notification;
- running two watchers at once;
- data is lost on `docker rm`;
- the waiting list works for searches run **inside the service** (`docker exec app
  bin/route_finder`); a one-off `docker run -i --rm` answers the search, but the
  request it saves lives only until that container is removed — no shared volume, by
  choice, for simplicity;
- a feed that changes while the watcher is down, followed by a CLI search that finds
  the route, yields a redundant (but true) notification on the next start pass.

**Done when:** in the running `app` service, using `docker cp` and `docker exec`:
1. with a feed lacking `ETRB` (a throwaway copy made for the demo, not stored in the
   repository), searching `CNSHA → BRSSZ` (`cheapest`) prints
   `[]` and creates `waiting_list/CNSHA_BRSSZ_cheapest.json`;
2. copying in the full `response.json` makes the watcher create
   `notifications/CNSHA_BRSSZ_cheapest.json` with the route in README format, and the
   waiting-list file is gone;
3. copying in the same feed again produces nothing new.

Separately, the phase-3 `docker run -i --rm` command still answers a search.
`data/response.json` in the repository is never modified.

**Ruby introduced:** file IO, `File.open` with a block, `File.rename`, `Dir.glob`, `FileUtils.mkdir_p`. In the shell
script: the shebang, `inotifywait -m`, the pipe `|`, `while read`.

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then implement **Phase 8** exactly as its
> section specifies, keeping to its minimal footprint: create only the files it lists
> and edit only the files it lists. Explain, before coding, the trade-offs accepted by choosing files and
> inotify (and what you would use instead if Docker were not the only guaranteed
> tool). Demonstrate the three-step scenario from "Done when" with real commands and
> real output. Leave the changes uncommitted.

---

## Phase 9 — Hardening and submission

**Goal:** make it a submission rather than a working program.

**Scope:**
1. Edge cases, each with a spec: unknown port code, origin equal to destination, no
   route for the criteria, a sailing with no rate, a departure date with no exchange
   rate, malformed input (fewer than three lines), unknown criteria.
2. SimpleCov wired in, coverage reported, gaps either closed or justified.
3. `docs/NOTES.md`: every assumption in force, every question sent to the PO, the
   README-versus-feed contradiction on `fastest`, the duplicate-rate decision, the
   same-day transfer assumption (and why there is no `TransferPolicy` object), and the
   trade-offs for saved searches. This is the document that backs the live walkthrough.
4. Submission `README` section: how to build, how to run, how to test.
5. Comments reduced to a minimal English form: a short header per file, one line on key
   methods, architecture and logic only. Verify no Cyrillic remains.
6. Move the debug scripts under a clearly marked `bin/debug/`.
7. Confirm a single branch and a clean history, and produce the zip (not sent).

**Decisions taken in stage 1 (2026-10-19):**
- The user sees only the route, `[]`, or a one-line input error with exit code 1.
  Everything meant for the administrator goes to `data/logs/route_finder.log`
  (stdlib `Logger`), written by both `bin/route_finder` and `bin/process_waiting_list`.
  The phase-8 stderr note about the waiting list moves to the log.
- Input: port codes are upper-cased once, on input, and must have the UN/LOCODE shape
  `[A-Z]{2}[A-Z0-9]{3}`; origin equal to destination, a missing or blank line and an
  unknown criteria are input errors. The criteria stays case-sensitive.
- Dirty feed data: a broken document (unreadable, not JSON, missing sections) is an
  empty feed; a dirty record (missing field, bad date, arrival not after departure, no
  or invalid rate, no exchange rate, a non-positive exchange rate) is dropped for every
  criteria. Both are logged; a search that finds nothing returns `[]` and waits in the
  waiting list. **Modifies phase-5 code:** `Loader` no longer raises on an inverted
  sailing.
- `RouteFinder::Application` becomes the single composition root for both entry points.
- Coverage thresholds: 100% line and 100% branch coverage of `lib/`.

**Prompt (stage 2, after the go-ahead):**
> Read `CLAUDE.md` and `docs/PLAN.md`, then execute **Phase 9** as its section
> specifies. After the comment pass, grep the repository and prove no Cyrillic remains,
> and prove the pass changed only comments. Write `docs/NOTES.md` for the
> reviewer — English, concise, one short section per decision with its justification —
> and list anything not fixed and why. Build the zip but do not send it.

---

## Working rules for every phase

- Never write anything during stage 1. Code starts only on an explicit go-ahead.
- One git commit per phase, all on a single branch, as README requirement 2 demands.
- Never implement a later phase's scope early. If a phase feels blocked by a missing
  piece, say so instead of widening the work.
- If a phase forces a change to code from an earlier phase, that is a signal worth
  reporting explicitly — it usually means an abstraction was drawn in the wrong place.
- The sample feed `response.json` (`data/response.json` from phase 8 on) is never edited. Synthetic cases go in
  `spec/fixtures/`.
- Every phase ends by actually running the "Done when" commands in Docker and showing
  their real output — not by asserting that they would pass.
