# Sailing route finder

All four tickets are implemented (cheapest-direct, cheapest, fastest, saved searches). Every
assumption and trade-off is in [docs/NOTES.md](docs/NOTES.md); the phased plan the work
followed is in [docs/PLAN.md](docs/PLAN.md). Only Docker is needed.

### Build

```sh
docker build -t sailing-route-finder .
```

### Run a search (stdin → stdout)

```sh
printf 'CNSHA\nNLRTM\ncheapest-direct\n' | docker run -i --rm sailing-route-finder
printf 'CNSHA\nNLRTM\ncheapest\n'        | docker run -i --rm sailing-route-finder
printf 'CNSHA\nNLRTM\nfastest\n'         | docker run -i --rm sailing-route-finder
```

The output is the JSON array from the tickets, or `[]` when there is no route yet.
Invalid input prints one line on stderr and exits with code 1. The sample feed is
`data/response.json`; set `FEED_PATH` to use another one.

### Run the waiting-list service (saved searches)

A search with no route is saved; when the feed changes, every saved search that can now
be served moves to `data/notifications/`, holding the same JSON a search would print.

```sh
docker run -d --name app --init --restart unless-stopped sailing-route-finder bin/watch_feed

printf 'CNSHA\nBRSSZ\ncheapest-direct\n' | docker exec -i app bin/route_finder   # [] and saved
docker cp new_feed.json app:/app/data/response.json                              # a new feed arrives
docker exec app ls data/waiting_list data/notifications
docker exec app cat data/logs/route_finder.log                                   # what happened, and any dirty feed data

docker stop app && docker rm app
```

### Test

```sh
docker run --rm sailing-route-finder bundle exec rspec
```

The suite enforces 100% line and branch coverage of `lib/`, so run it whole: a single
spec file on its own reports a coverage failure.

### Layout

| path | what |
|---|---|
| `bin/route_finder` | the CLI |
| `bin/watch_feed`, `bin/process_waiting_list` | the waiting-list service and one pass of it |
| `bin/debug/` | debugging tools (EUR cost table, event-graph dump), not part of the CLI |
| `lib/route_finder/application.rb` | the composition root |
| `lib/route_finder/feed/` | feed loading, rates, exchange rates, EUR costs |
| `lib/route_finder/graph/`, `shortest_path/`, `weights/` | the event graph, Dijkstra, edge weights |
| `lib/route_finder/criteria/`, `criteria_factory.rb` | the search criteria and their registry |
| `lib/route_finder/waiting_list.rb` | saved searches and notifications |

---

## The problem

A rates feed (`data/response.json`) lists ocean sailings between ports, the rate of each
sailing in its own currency, and daily EUR exchange rates. The rate of a sailing is
converted to EUR with the exchange rate of its departure date. Given an origin port, a
destination port and a criterion on stdin, the CLI prints the matching sailing legs as JSON:

| Criterion | Returns |
|---|---|
| `cheapest-direct` | the cheapest single sailing between the two ports |
| `cheapest` | the cheapest route, direct or with transfers (sum of all legs in EUR) |
| `fastest` | the route with the shortest total journey time, direct or with transfers |

A search that has no route yet is saved to a waiting list and fulfilled automatically
when a newer feed makes it possible (see "Run the waiting-list service" above).

Routes with transfers are found with Dijkstra over a time-expanded graph, so a
connecting leg can only depart after the previous one arrives. Design decisions and
trade-offs are in [docs/NOTES.md](docs/NOTES.md).

