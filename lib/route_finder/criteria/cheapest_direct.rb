# frozen_string_literal: true

module RouteFinder
  module Criteria
    # cheapest-direct: the cheapest direct sailing. A filter plus a minimum, deliberately no graph.
    # Contract of every criteria: new(sailings, cost_calculator) and
    # find_route(origin, destination) returning the sailings in travel order, [] for no route.
    class CheapestDirect
      def initialize(sailings, cost_calculator)
        @sailings = sailings
        @cost_calculator = cost_calculator
      end

      def find_route(origin_port, destination_port)
        direct_sailings = direct_between(origin_port, destination_port)

        if direct_sailings.empty?
          return []
        end

        cheapest = direct_sailings.min_by do |sailing|
          sort_key(sailing)
        end

        return [cheapest]
      end

      private

      def direct_between(origin_port, destination_port)
        direct_sailings = @sailings.select do |sailing|
          sailing.origin_port == origin_port && sailing.destination_port == destination_port
        end
        return direct_sailings
      end

      # Cheapest in EUR; a tie goes to the earlier departure, then to the lower code (our
      # assumption), so the answer never depends on the order of the feed.
      def sort_key(sailing)
        eur_cost = @cost_calculator.cost_of(sailing)
        return [eur_cost.amount, sailing.departure_date, sailing.sailing_code]
      end
    end
  end
end
