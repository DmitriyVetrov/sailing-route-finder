# Notes: assumptions, decisions and trade-offs

Every decision behind the solution, one short section each. Anything marked
*assumption* is ours: the README does not settle it.

## 1. Architecture in brief

- **Time-expanded event graph.** A vertex is `(port, date)`: "being in this port on this
  day". Edges are sailings, waiting in a port until its next event (forward only), and
  wiring from a SOURCE to every origin event and from every destination event to a SINK.
  "The ship left before you arrived" is therefore a *missing edge*, not a check in the
  search, so every path is a feasible journey.
- **One generic Dijkstra** over that graph. It knows two collaborators only:
  `edges_from(node)` and `weight_of(edge)`, and a weight only needs `+` and `<=>`.
  It knows nothing about ports, money or dates.
- **Criteria** (`cheapest-direct`, `cheapest`, `fastest`) are registered by name in
  `CriteriaFactory`. The two graph criteria differ only in how they weigh an edge
  (Template Method in `GraphRouteSearch`, the criteria passed to Dijkstra as a Strategy).
- Every point the README leaves open sits behind a replaceable object: the duplicate-rate
  resolver, the weight types and the criteria registry.

Why not enumerate all paths: the number of paths grows exponentially with the legs, and
the README requires routes with more than two legs. A spec covers a three-leg route on a
synthetic feed.

## 2. Money and currency

- Amounts are `BigDecimal`, never `Float`; they are rounded only for display.
- The README states that exchange rates are EUR-based and picked by the sailing's
  `departure_date`. `"usd": 1.1138` means 1 EUR = 1.1138 USD, so EUR = amount / rate.
- That rule lives in one place, `EurCostCalculator`.
- Comparing two amounts in different currencies raises an error instead of guessing.

## 3. The output echoes the original rate

The README's cheapest example prints ETRG as `"69.96"` `"USD"`, so the output shows each
leg's rate exactly as the feed has it. EUR is used only internally, for comparison.
`Money` keeps the original text, because `BigDecimal("589.30")` prints as `589.3`.

## 4. Duplicate rates: the highest wins

`MNOP` has two rates (456.78 and 812.00 USD). The PO confirmed the duplicate is
intentional and the higher rate wins. `HighestRate` is a resolver injected into
`RateBook`. A spec swaps in a lowest-rate resolver, and with it `cheapest-direct`
answers MNOP instead of ABCD with no code change.

## 5. README example values (*assumption*)

- The generic example's `"rate": "123.00"` and cheapest-direct's `"232.30"`, with `XXXX` and
  2024 dates, are read as placeholders.
- On the sample feed, `cheapest-direct` CNSHA→NLRTM is **ABCD, 589.30 USD (523.36 EUR)**.

## 6. `cheapest` matches the README, except one date

The answer is **ERXQ + ETRG = 261.96 + 60.93 = 322.89 EUR**, the same legs as the README.
The README prints ERXQ arriving 2022-02-06, but the feed says 2022-02-12; we print the
feed.

## 7. `fastest` contradicts the README

Fastest means first departure to final arrival, **waiting included** (confirmed by
the PO: "the waiting time counts"). On the sample feed:

| route | departs | arrives | days |
|---|---|---|---|
| QRST (direct) | 2022-01-29 | 2022-02-15 | **17** |
| ERXQ + ETRG | 2022-01-29 | 2022-02-20 | 22 (18 without the layover) |

QRST wins under both readings. The README's output for fastest is identical to
cheapest's; we read it as a copy-paste (*assumption*). We return QRST and say so in a
spec, rather than bending the feed or the definition. Measuring time at sea only would
mean changing one line: the waiting-edge weight in `Fastest`.

## 8. Same-day transfers; why there is no `TransferPolicy` (*assumption*)

- Arriving on day D and leaving on day D is allowed. The feed has dates only, and an
  arrival and a departure on the same date are the same vertex.
- A `TransferPolicy` object could never say "no" in this model, so it is not built.
- A minimum connection time would need `(port, date, kind)` vertices plus a transfer edge
  from each arrival to the earliest allowed departure. That is the extension point.

## 9. Deterministic ties (*assumption*)

- `cheapest` and `fastest`: equal totals go to the route with fewer legs. The leg count is
  the second component of the weight, so the search loop has no special cases.
- `cheapest-direct`: equal prices go to the earlier departure, then the lower code.
- Equal queue priorities leave in insertion order.
- Together, the same input always gives the same answer.

## 10. Input contract

- Three lines (origin, destination, criteria). Surrounding spaces and `\r` are ignored;
  lines after the third are ignored.
- Port codes are upper-cased on input and must have the UN/LOCODE shape `[A-Z]{2}[A-Z0-9]{3}`
  (*assumption*, matching every code in the README and the feed).
- A missing or blank line, a malformed port, origin equal to destination, or an unknown
  criteria is an **input error**: one line on stderr, nothing on stdout, exit code 1,
  nothing saved.
- The criteria name is case-sensitive, as the README spells it.
- A well-formed port that is not in the feed is **not** an error: it is "no route yet"
  (see 12). A later feed may serve it.
- stdout carries JSON only. "No route" prints `[]` with exit code 0: it is an answer,
  not a failure.
- Three command-line arguments may replace the three stdin lines. This is a debugging
  convenience; stdin stays the contract.

## 11. Dirty feed data and the log

The README warns that the feed "is not guaranteed to be clean". The user only ever sees
a route or `[]`. Data problems are for the administrator:

- **Broken document** (unreadable file, not JSON, a missing or wrongly typed `sailings`,
  `rates` or `exchange_rates`): the feed is treated as empty.
- **Dirty record**, dropped for every criteria:
  - a sailing with a missing field, a non-ISO date, or an arrival not after departure;
  - a rate that is missing, not a number, negative, or whose duplicates disagree on the
    currency;
  - a sailing with no rate, or no exchange rate for its currency on its departure date;
  - an exchange rate that is not a positive number (zero would divide by zero).
- Each problem is written to `data/logs/route_finder.log` (stdlib `Logger`) by whichever
  process loaded the feed. Every line is tagged `route_finder` or `process_waiting_list`.
- A search that finds nothing returns `[]` and is saved to the waiting list, so it is
  fulfilled once the feed is fixed.
- Trade-offs:
  - A sailing without an exchange rate is dropped for `fastest` too, although fastest
    does not need EUR. One clean set of sailings for every criteria is easier to reason
    about than criteria-specific views of the data.
  - One malformed record does not stop the rest of the feed, but it is only logged; a
    real system would also quarantine it and alert someone.
  - The same problems are logged again by every process that loads the same feed.

## 12. saved searches: saved searches

The README leaves both mechanisms open ("Docker is the only thing we can assume").
The PO confirmed it is our call.

**Flow.**
1. A search with no route prints `[]` and is saved as
   `data/waiting_list/<ORIGIN>_<DEST>_<criteria>.json`. The file holds the request.
   Saving the same search again overwrites the same file.
2. `bin/watch_feed` is the service's main process. At start, and whenever the feed file
   is replaced (inotify `close_write` / `moved_to` on the feed's directory), it runs
   `bin/process_waiting_list`. That re-runs every saved search in-process, with the same
   factory and presenter the CLI uses.
3. A search that now has a route **moves** to `data/notifications/`, under the same name,
   holding exactly the JSON the CLI would print. The notification is written first
   (temp file + `rename`, so it is never half-written) and the request deleted after. A
   crash in between reprocesses the request but never loses it.

**Why files and inotify.**
- Nothing to install besides Docker; the data is plain text that anyone can inspect.
- Change detection is the kernel's job: instant, fired only after the writer closed the
  file, with no polling loop to write.

**Alternatives considered.**
- SQLite: queryable, but a new dependency and schema for a handful of records.
- Redis or a queue: a second container, beyond "only Docker".
- Polling the feed's mtime: only needed when the feed lives on a Mac/Windows host
  volume, where inotify is unreliable.
- A webhook or email for notifying: needs an endpoint or credentials we do not have.

**The SOLID cost, stated openly.** `WaitingList` holds storage, delivery and the pass in
one class to keep the footprint small.
- If the next requirement is a database or a webhook, the cut lines are known: `fulfil`
  becomes a `Notifier`, `process` becomes a `Fulfiller`.
- The CLI depends only on `save` (constructor-injected), so it would not change.
- A new criteria works for saved searches with no change at all.

**Out of scope for v1.**
- The notification life cycle: read, dismissed, expiry.
- Re-saving a search that was already fulfilled overwrites its earlier notification.
- Two watchers running at once.
- Data lives in the container (no volume): it survives `docker stop/start` and restarts,
  and is gone after `docker rm`.
- A one-off `docker run -i --rm` answers the search, but the search it saves lives only as
  long as that container. Saved searches are meant to be run inside the service
  (`docker exec app bin/route_finder`).
- A feed changed while the watcher is down, followed by a CLI search that finds the route,
  can yield a redundant (but true) notification on the next start.
- The log file is not rotated.

## 13. Docker

- One image, two roles. `CMD ["bin/route_finder"]` runs a search, and anything after the
  image name replaces it: `bundle exec rspec` runs the tests, `bin/watch_feed` runs the
  service. `ENTRYPOINT` would have turned those commands into arguments.
- Multi-stage build: the compiler that `bigdecimal`'s native extension needs stays in
  the builder stage.
- No Compose: one service needs none.

## 14. Extending

- **A new criteria:** one class answering `find_route` plus one line in
  `CriteriaFactory::CRITERIA`. A graph criteria only defines `weight_of` and
  `zero_weight`. `fastest` was added exactly this way, with no change to the graph,
  Dijkstra or the CLI.
- **A new weight type:** must pass the shared weight contract spec, in particular
  monotonicity (`a <= b` implies `a + c <= b + c`), which Dijkstra's correctness rests on.

## 15. Tests and coverage

- 296 examples. 100% line and 100% branch coverage of `lib/` (SimpleCov), enforced: the
  suite fails below 100%. As a consequence, running a single spec file reports a coverage
  failure; the threshold is meant for the full suite.
- The README searches are asserted end to end: the real `bin/route_finder` runs as a
  separate process. The same goes for `bin/process_waiting_list`.
- `data/response.json` is never modified. Dirty and synthetic feeds are built inside the
  specs or kept in `spec/fixtures/`.
- Not covered automatically:
  - `bin/watch_feed` (shell and inotify), which needs a running watcher and real file
    events. It was demonstrated manually.
  - `bin/debug/*`, debugging tools outside the CLI contract.
- 100% coverage means no line or branch is unexecuted, not that there are no bugs. The
  valuable tests are the README searches, the contracts and the edge cases.

## 16. Questions for the PO

Asked during the assignment and answered by the PO:

- Does waiting time count towards "fastest"? Yes (section 7).
- Which of two conflicting rates for one sailing wins? The higher one (section 4).
- How should saved searches be persisted and surfaced? Our call (section 12).

## 17. Not fixed, on purpose

- `TimeExpandedGraph` is rebuilt per search and mixes feed data with the query. It is
  simple, and fast enough for the feed's size.
- The priority queue is a sorted array (O(n) insert), chosen for readability. Only that
  class would change for a binary heap.
- `WaitingList` is one class doing three jobs; see 12.
- The log repeats the same data problems on every load; see 11.

## 18. How AI was used

The work was planned and executed in nine phases (`docs/PLAN.md`) with an AI assistant
(Claude Code), guided by `CLAUDE.md`. Each phase's plan was reviewed and its open
decisions settled before any code was written. Every decision above was taken by the
author, who can explain each one.
