# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Criteria::Cheapest do
  let(:day) { Date.new(2022, 2, 1) }

  let(:exchange_rates) do
    RouteFinder::Feed::ExchangeRates.new(
      day => { "USD" => BigDecimal("1.0") }
    )
  end

  def criteria_for(sailings, prices)
    calculator = RouteFinder::Feed::EurCostCalculator.new(rate_book_from(prices), exchange_rates)
    return RouteFinder::Criteria::Cheapest.new(sailings, calculator)
  end

  describe "#find_route" do
    it "returns a direct sailing when it is the only option" do
      sailings = [sailing("DIRC", "AAAAA", "BBBBB", day, day + 20)]
      criteria = criteria_for(sailings, { "DIRC" => ["100", "EUR"] })

      route = criteria.find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["DIRC"])
    end

    it "prefers a cheaper two-leg route over a more expensive direct one" do
      sailings = [
        sailing("DIRC", "AAAAA", "BBBBB", day, day + 20),
        sailing("LEG1", "AAAAA", "CCCCC", day, day + 5),
        sailing("LEG2", "CCCCC", "BBBBB", day + 5, day + 10)
      ]
      prices = { "DIRC" => ["500", "EUR"], "LEG1" => ["50", "EUR"], "LEG2" => ["50", "EUR"] }

      route = criteria_for(sailings, prices).find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["LEG1", "LEG2"])
    end

    it "waits in a port for a later connection instead of refusing the route" do
      sailings = [
        sailing("LEG1", "AAAAA", "CCCCC", day, day + 3),
        sailing("LEG2", "CCCCC", "BBBBB", day + 7, day + 10)
      ]
      prices = { "LEG1" => ["50", "EUR"], "LEG2" => ["50", "EUR"] }

      route = criteria_for(sailings, prices).find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["LEG1", "LEG2"])
    end

    it "returns an empty list when the destination is unreachable" do
      sailings = [sailing("LEG1", "AAAAA", "CCCCC", day, day + 5)]
      criteria = criteria_for(sailings, { "LEG1" => ["10", "EUR"] })

      expect(criteria.find_route("AAAAA", "BBBBB")).to eq([])
    end

    it "returns an empty list for an empty feed" do
      expect(criteria_for([], {}).find_route("AAAAA", "BBBBB")).to eq([])
    end
  end

  describe "#weight_of (the weigher protocol Dijkstra expects, see shortest_path/dijkstra.rb)" do
    it "weighs a sailing edge by its EUR cost, with one leg" do
      ride = sailing("AAAA", "AAAAA", "BBBBB", day, day + 1)
      criteria = criteria_for([ride], { "AAAA" => ["100", "EUR"] })
      edge = RouteFinder::Graph::Edge.sailing(
        RouteFinder::Graph::Node.new("AAAAA", day),
        RouteFinder::Graph::Node.new("BBBBB", day + 1),
        ride
      )

      weight = criteria.weight_of(edge)

      expect(weight.amount).to eq(BigDecimal("100"))
      expect(weight.legs).to eq(1)
    end

    it "weighs a waiting edge as zero (waiting in port is free)" do
      criteria = criteria_for([], {})
      edge = RouteFinder::Graph::Edge.waiting(
        RouteFinder::Graph::Node.new("AAAAA", day),
        RouteFinder::Graph::Node.new("AAAAA", day + 1)
      )

      expect(criteria.weight_of(edge)).to eq(RouteFinder::Weights::MoneyWeight.zero)
    end

    it "weighs an endpoint edge (SOURCE/SINK) as zero: it is not a real sailing" do
      criteria = criteria_for([], {})
      edge = RouteFinder::Graph::Edge.endpoint(
        RouteFinder::Graph::EndpointNode.new("SOURCE"),
        RouteFinder::Graph::Node.new("AAAAA", day)
      )

      expect(criteria.weight_of(edge)).to eq(RouteFinder::Weights::MoneyWeight.zero)
    end
  end

  describe "on the real sample feed (response.json)" do
    def criteria_from_sample_feed
      loader = load_sample_feed
      return RouteFinder::Criteria::Cheapest.new(loader.sailings, cost_calculator_for(loader))
    end

    it "picks ERXQ + ETRG (322.89 EUR), beating the best direct sailing ABCD (523.36 EUR)" do
      criteria = criteria_from_sample_feed

      route = criteria.find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["ERXQ", "ETRG"])
    end

    it "keeps the feed's own ERXQ arrival date (2022-02-12), not the README's printed 2022-02-06" do
      criteria = criteria_from_sample_feed
      route = criteria.find_route("CNSHA", "NLRTM")

      erxq = route.find { |leg| leg.sailing_code == "ERXQ" }
      expect(erxq.arrival_date.iso8601).to eq("2022-02-12")
    end
  end

  describe "a route of more than two legs (README requirement 6)" do
    it "assembles three legs when they are cheaper than any shorter alternative" do
      loader = load_feed(three_leg_feed_path, highest_rate)
      criteria = RouteFinder::Criteria::Cheapest.new(loader.sailings, cost_calculator_for(loader))

      route = criteria.find_route("AAAAA", "DDDDD")

      expect(codes_of(route)).to eq(["LEG1", "LEG2", "LEG3"])
    end
  end
end
