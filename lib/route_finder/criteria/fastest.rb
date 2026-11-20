# frozen_string_literal: true

require_relative "graph_route_search"
require_relative "../weights/duration_weight"

module RouteFinder
  module Criteria
    # fastest: the fastest route, from the first departure to the final arrival.
    # Edge weights are day differences, so along any path they add up to exactly that span.
    # Same graph and Dijkstra as Cheapest; only weight_of differs.
    class Fastest < GraphRouteSearch
      def weight_of(edge)
        if edge.endpoint?
          return zero_weight
        end

        # Waiting in port counts (confirmed by the PO). Weighing it zero instead would measure
        # time at sea only; nothing else would have to change.
        if edge.waiting?
          waiting_days = (edge.to.date - edge.from.date).to_i
          return Weights::DurationWeight.new(waiting_days, 0)
        end

        return Weights::DurationWeight.new(edge.sailing.duration_days, 1)
      end

      def zero_weight
        return Weights::DurationWeight.zero
      end
    end
  end
end
