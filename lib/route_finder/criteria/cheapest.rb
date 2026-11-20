# frozen_string_literal: true

require_relative "graph_route_search"
require_relative "../weights/money_weight"

module RouteFinder
  module Criteria
    # cheapest: the cheapest route, direct or with transfers. Sailing edges cost their EUR
    # price; waiting in port and the SOURCE/SINK edges cost nothing.
    class Cheapest < GraphRouteSearch
      def weight_of(edge)
        if !edge.sailing?
          return zero_weight
        end

        eur_cost = @cost_calculator.cost_of(edge.sailing)

        # The leg count only breaks ties between equally cheap routes.
        return Weights::MoneyWeight.new(eur_cost.amount, 1)
      end

      def zero_weight
        return Weights::MoneyWeight.zero
      end
    end
  end
end
