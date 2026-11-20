# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Criteria::CheapestDirect do
  let(:day) { Date.new(2022, 2, 1) }

  let(:exchange_rates) do
    RouteFinder::Feed::ExchangeRates.new(
      day => { "USD" => BigDecimal("1.0"), "GBP" => BigDecimal("0.5") }
    )
  end

  def direct_sailing(code, origin, destination, departure_date = day)
    return sailing(code, origin, destination, departure_date, departure_date + 10)
  end

  def criteria_for(sailings, prices)
    calculator = RouteFinder::Feed::EurCostCalculator.new(rate_book_from(prices), exchange_rates)
    return RouteFinder::Criteria::CheapestDirect.new(sailings, calculator)
  end

  describe "#find_route" do
    it "returns the cheapest of several direct sailings, as a one-element list" do
      sailings = [direct_sailing("AAAA", "CNSHA", "NLRTM"), direct_sailing("BBBB", "CNSHA", "NLRTM")]
      prices = { "AAAA" => ["200", "EUR"], "BBBB" => ["150", "EUR"] }
      criteria = criteria_for(sailings, prices)

      route = criteria.find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["BBBB"])
    end

    it "compares prices in EUR, not the raw numbers of different currencies" do
      sailings = [direct_sailing("GBPP", "CNSHA", "NLRTM"), direct_sailing("EURR", "CNSHA", "NLRTM")]
      prices = { "GBPP" => ["90", "GBP"], "EURR" => ["100", "EUR"] }
      criteria = criteria_for(sailings, prices)

      route = criteria.find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["EURR"])
    end

    it "ignores sailings on other routes, even much cheaper ones" do
      sailings = [
        direct_sailing("DIRC", "CNSHA", "NLRTM"),
        direct_sailing("LEG1", "CNSHA", "ESBCN"),
        direct_sailing("LEG2", "ESBCN", "NLRTM")
      ]
      prices = { "DIRC" => ["500", "EUR"], "LEG1" => ["10", "EUR"], "LEG2" => ["10", "EUR"] }

      route = criteria_for(sailings, prices).find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["DIRC"])
    end

    it "does not use a sailing in the opposite direction" do
      sailings = [direct_sailing("BACK", "NLRTM", "CNSHA")]
      criteria = criteria_for(sailings, { "BACK" => ["10", "EUR"] })

      expect(criteria.find_route("CNSHA", "NLRTM")).to eq([])
    end

    it "returns an empty list when there is no direct sailing" do
      sailings = [direct_sailing("LEG1", "CNSHA", "ESBCN")]
      criteria = criteria_for(sailings, { "LEG1" => ["10", "EUR"] })

      expect(criteria.find_route("CNSHA", "NLRTM")).to eq([])
    end

    it "returns an empty list for an empty feed" do
      criteria = criteria_for([], {})

      expect(criteria.find_route("CNSHA", "NLRTM")).to eq([])
    end

    describe "tie-breaking (an assumption of ours: the task says nothing about equal prices)" do
      it "prefers the earlier departure when prices are equal" do
        sailings = [
          direct_sailing("LATE", "CNSHA", "NLRTM", day),
          direct_sailing("EARL", "CNSHA", "NLRTM", day - 1)
        ]
        prices = { "LATE" => ["100", "EUR"], "EARL" => ["100", "EUR"] }

        route = criteria_for(sailings, prices).find_route("CNSHA", "NLRTM")

        expect(codes_of(route)).to eq(["EARL"])
      end

      it "prefers the smaller sailing code when price and departure are both equal" do
        sailings = [direct_sailing("ZZZZ", "CNSHA", "NLRTM"), direct_sailing("AAAA", "CNSHA", "NLRTM")]
        prices = { "ZZZZ" => ["100", "EUR"], "AAAA" => ["100", "EUR"] }

        route = criteria_for(sailings, prices).find_route("CNSHA", "NLRTM")

        expect(codes_of(route)).to eq(["AAAA"])
      end

      it "gives the same answer whatever the order of sailings in the feed" do
        first = direct_sailing("AAAA", "CNSHA", "NLRTM")
        second = direct_sailing("ZZZZ", "CNSHA", "NLRTM")
        prices = { "AAAA" => ["100", "EUR"], "ZZZZ" => ["100", "EUR"] }

        forward = criteria_for([first, second], prices).find_route("CNSHA", "NLRTM")
        backward = criteria_for([second, first], prices).find_route("CNSHA", "NLRTM")

        expect(codes_of(forward)).to eq(codes_of(backward))
      end
    end
  end

  describe "on the real sample feed (response.json)" do
    def criteria_with(resolver)
      loader = load_feed(sample_feed_path, resolver)
      return RouteFinder::Criteria::CheapestDirect.new(loader.sailings, cost_calculator_for(loader))
    end

    it "picks ABCD (523.36 EUR) for CNSHA -> NLRTM when the higher duplicate rate wins" do
      criteria = criteria_with(highest_rate)

      route = criteria.find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["ABCD"])
    end

    it "would pick MNOP (410.11 EUR) under a lowest-rate policy" do
      criteria = criteria_with(LowestRateResolver.new)

      route = criteria.find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["MNOP"])
    end

    it "finds the only direct sailing for CNSHA -> ESBCN" do
      criteria = criteria_with(highest_rate)

      expect(codes_of(criteria.find_route("CNSHA", "ESBCN"))).to eq(["ERXQ"])
    end

    it "finds no direct sailing for CNSHA -> BRSSZ (it is reachable only via ESBCN)" do
      criteria = criteria_with(highest_rate)

      expect(criteria.find_route("CNSHA", "BRSSZ")).to eq([])
    end
  end
end
