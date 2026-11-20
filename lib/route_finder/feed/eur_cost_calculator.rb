# frozen_string_literal: true

module RouteFinder
  module Feed
    # A sailing's cost in EUR: its rate converted on its departure date (the README rule).
    # One place for the rule, shared by CheapestDirect, Cheapest and the debug table.
    # EUR is internal only; the output echoes the original rate.
    class EurCostCalculator
      def initialize(rate_book, exchange_rates)
        @rate_book = rate_book
        @exchange_rates = exchange_rates
      end

      # Not rounded: comparisons use exact amounts.
      def cost_of(sailing)
        rate = @rate_book.rate_for(sailing.sailing_code)
        return @exchange_rates.to_eur(rate, sailing.departure_date)
      end
    end
  end
end
