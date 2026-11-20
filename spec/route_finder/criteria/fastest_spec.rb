# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Criteria::Fastest do
  let(:day) { Date.new(2022, 2, 1) }

  def criteria_for(sailings)
    return RouteFinder::Criteria::Fastest.new(sailings, nil)
  end

  describe "#find_route" do
    it "returns a direct sailing when it is the only option" do
      sailings = [sailing("DIRC", "AAAAA", "BBBBB", day, day + 20)]

      route = criteria_for(sailings).find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["DIRC"])
    end

    it "prefers a faster two-leg route over a slower direct one" do
      sailings = [
        sailing("DIRC", "AAAAA", "BBBBB", day, day + 20),
        sailing("LEG1", "AAAAA", "CCCCC", day, day + 2),
        sailing("LEG2", "CCCCC", "BBBBB", day + 2, day + 5)
      ]

      route = criteria_for(sailings).find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["LEG1", "LEG2"])
    end

    it "counts a long layover against the route, unlike Cheapest (the waiting time counts)" do
      sailings = [
        sailing("LEG1", "AAAAA", "CCCCC", day, day + 2),
        sailing("LEG2", "CCCCC", "BBBBB", day + 10, day + 12),
        sailing("DIRC", "AAAAA", "BBBBB", day, day + 9)
      ]

      route = criteria_for(sailings).find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["DIRC"])
    end

    it "breaks a tie in total duration by the number of legs" do
      sailings = [
        sailing("DIRC", "AAAAA", "BBBBB", day, day + 10),
        sailing("LEG1", "AAAAA", "CCCCC", day, day + 5),
        sailing("LEG2", "CCCCC", "BBBBB", day + 5, day + 10)
      ]

      route = criteria_for(sailings).find_route("AAAAA", "BBBBB")

      expect(codes_of(route)).to eq(["DIRC"])
    end

    it "returns an empty list when the destination is unreachable" do
      sailings = [sailing("LEG1", "AAAAA", "CCCCC", day, day + 5)]

      expect(criteria_for(sailings).find_route("AAAAA", "BBBBB")).to eq([])
    end

    it "returns an empty list for an empty feed" do
      expect(criteria_for([]).find_route("AAAAA", "BBBBB")).to eq([])
    end
  end

  describe "#weight_of (the weigher protocol Dijkstra expects, see shortest_path/dijkstra.rb)" do
    it "weighs a sailing edge by its duration in days, with one leg" do
      ride = sailing("AAAA", "AAAAA", "BBBBB", day, day + 7)
      edge = RouteFinder::Graph::Edge.sailing(
        RouteFinder::Graph::Node.new("AAAAA", day),
        RouteFinder::Graph::Node.new("BBBBB", day + 7),
        ride
      )

      weight = criteria_for([]).weight_of(edge)

      expect(weight.days).to eq(7)
      expect(weight.legs).to eq(1)
    end

    it "weighs a waiting edge by the layover in days with zero legs -- NOT zero, unlike Cheapest" do
      edge = RouteFinder::Graph::Edge.waiting(
        RouteFinder::Graph::Node.new("AAAAA", day),
        RouteFinder::Graph::Node.new("AAAAA", day + 4)
      )

      weight = criteria_for([]).weight_of(edge)

      expect(weight.days).to eq(4)
      expect(weight.legs).to eq(0)
    end

    it "weighs an endpoint edge (SOURCE/SINK) as zero: it is not part of the journey" do
      edge = RouteFinder::Graph::Edge.endpoint(
        RouteFinder::Graph::EndpointNode.new("SOURCE"),
        RouteFinder::Graph::Node.new("AAAAA", day)
      )

      expect(criteria_for([]).weight_of(edge)).to eq(RouteFinder::Weights::DurationWeight.zero)
    end
  end

  # The README prints ERXQ + ETRG for fastest, but on the feed ERXQ arrives 2022-02-12, so
  # that route takes 22 days (18 without the layover) against QRST's 17.
  describe "on the real sample feed (response.json)" do
    def criteria_from_sample_feed
      return RouteFinder::Criteria::Fastest.new(load_sample_feed.sailings, nil)
    end

    it "picks the direct QRST (17 days), not the README's printed ERXQ+ETRG" do
      criteria = criteria_from_sample_feed

      route = criteria.find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["QRST"])
    end

    it "takes exactly 17 days, first departure to final arrival" do
      criteria = criteria_from_sample_feed
      route = criteria.find_route("CNSHA", "NLRTM")

      qrst = route.first
      total_days = (qrst.arrival_date - qrst.departure_date).to_i

      expect(total_days).to eq(17)
      expect(qrst.departure_date.iso8601).to eq("2022-01-29")
      expect(qrst.arrival_date.iso8601).to eq("2022-02-15")
    end
  end
end
