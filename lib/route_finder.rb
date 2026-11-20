# frozen_string_literal: true

# Library root: the entry points and the specs require only this file.
require_relative "route_finder/cli"
require_relative "route_finder/errors"
require_relative "route_finder/money"
require_relative "route_finder/feed/sailing"
require_relative "route_finder/feed/exchange_rates"
require_relative "route_finder/feed/rate_resolvers/highest_rate"
require_relative "route_finder/feed/rate_book"
require_relative "route_finder/feed/loader"
require_relative "route_finder/feed/eur_cost_calculator"
require_relative "route_finder/criteria/cheapest_direct"
require_relative "route_finder/presenter/legs_presenter"
require_relative "route_finder/weights/money_weight"
require_relative "route_finder/weights/duration_weight"
require_relative "route_finder/shortest_path/priority_queue"
require_relative "route_finder/shortest_path/path"
require_relative "route_finder/shortest_path/dijkstra"
require_relative "route_finder/graph/node"
require_relative "route_finder/graph/endpoint_node"
require_relative "route_finder/graph/edge"
require_relative "route_finder/graph/time_expanded_graph"
require_relative "route_finder/criteria/graph_route_search"
require_relative "route_finder/criteria/cheapest"
require_relative "route_finder/criteria/fastest"
require_relative "route_finder/criteria_factory"
require_relative "route_finder/waiting_list"
require_relative "route_finder/application"

module RouteFinder
end
