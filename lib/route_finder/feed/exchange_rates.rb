# frozen_string_literal: true

require "bigdecimal"
require_relative "../errors"
require_relative "../money"

module RouteFinder
  module Feed
    # EUR-based exchange rates by date: "usd": 1.1138 on day D means 1 EUR = 1.1138 USD,
    # so EUR amount = amount / rate. The caller picks the date (the sailing's departure).
    class ExchangeRates
      BASE_CURRENCY = "EUR"

      # BigDecimal division needs an explicit precision (1/3 never ends);
      # rounding happens only for display.
      DIVISION_PRECISION = 20

      # rates_by_date: { Date => { "USD" => BigDecimal, "JPY" => BigDecimal } },
      # currency codes upper-cased by the Loader.
      def initialize(rates_by_date)
        @rates_by_date = rates_by_date
      end

      # Whether an amount in this currency can be converted to EUR on this date.
      def convertible?(currency, date)
        if currency == BASE_CURRENCY
          return true
        end

        rates_for_date = @rates_by_date.fetch(date, nil)
        if rates_for_date.nil?
          return false
        end
        return rates_for_date.key?(currency)
      end

      # Returns a new Money in EUR; amounts already in EUR need no rate.
      def to_eur(money, date)
        if money.currency == BASE_CURRENCY
          return money
        end

        rate = eur_rate(money.currency, date)

        eur_amount = money.amount.div(rate, DIVISION_PRECISION)
        return Money.new(eur_amount, BASE_CURRENCY)
      end

      # Units of the currency per 1 EUR on the date; raises when the feed has none.
      def eur_rate(currency, date)
        rates_for_date = @rates_by_date.fetch(date, nil)
        if rates_for_date.nil?
          raise ExchangeRateNotFoundError, "No exchange rates for #{date.iso8601}"
        end

        rate = rates_for_date.fetch(currency, nil)
        if rate.nil?
          raise ExchangeRateNotFoundError,
                "No #{currency} exchange rate for #{date.iso8601}"
        end

        return rate
      end
    end
  end
end
