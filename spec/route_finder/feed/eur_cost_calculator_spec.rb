# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Feed::EurCostCalculator do
  let(:departure_date) { Date.new(2022, 2, 1) }
  let(:arrival_date) { Date.new(2022, 3, 1) }

  let(:abcd) { sailing("ABCD", "CNSHA", "NLRTM", departure_date, arrival_date) }

  let(:exchange_rates) do
    RouteFinder::Feed::ExchangeRates.new(
      departure_date => { "USD" => BigDecimal("1.126") },
      arrival_date => { "USD" => BigDecimal("2.0") }
    )
  end

  def rate_book_with(code, text, currency)
    return rate_book_from({ code => [text, currency] })
  end

  def calculator_for(rate_book)
    return RouteFinder::Feed::EurCostCalculator.new(rate_book, exchange_rates)
  end

  describe "#cost_of" do
    it "converts the rate of the sailing at the rate of its DEPARTURE date" do
      calculator = calculator_for(rate_book_with("ABCD", "589.30", "USD"))

      cost = calculator.cost_of(abcd)

      expect(cost.currency).to eq("EUR")
      expect(cost.to_display_string).to eq("523.36")
    end

    it "returns a rate that is already in EUR as it is" do
      calculator = calculator_for(rate_book_with("ABCD", "761.96", "EUR"))

      cost = calculator.cost_of(abcd)

      expect(cost.currency).to eq("EUR")
      expect(cost.to_display_string).to eq("761.96")
    end

    it "uses the rate chosen by the duplicate policy (the higher one)" do
      candidates = {
        "ABCD" => [
          RouteFinder::Money.from_text("456.78", "USD"),
          RouteFinder::Money.from_text("812.00", "USD")
        ]
      }
      rate_book = RouteFinder::Feed::RateBook.new(
        candidates, highest_rate
      )

      cost = calculator_for(rate_book).cost_of(abcd)

      expect(cost.to_display_string).to eq("721.14")
    end

    it "raises when the feed has no rate for the sailing" do
      calculator = calculator_for(rate_book_with("OTHER", "10.00", "USD"))

      expect { calculator.cost_of(abcd) }.to raise_error(
        RouteFinder::RateNotFoundError, /ABCD/
      )
    end

    it "raises when there is no exchange rate for the departure date" do
      no_rates = RouteFinder::Feed::ExchangeRates.new({})
      calculator = RouteFinder::Feed::EurCostCalculator.new(
        rate_book_with("ABCD", "589.30", "USD"), no_rates
      )

      expect { calculator.cost_of(abcd) }.to raise_error(
        RouteFinder::ExchangeRateNotFoundError, /2022-02-01/
      )
    end
  end
end
