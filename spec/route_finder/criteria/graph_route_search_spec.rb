# frozen_string_literal: true

require "spec_helper"

class LegCountSearch < RouteFinder::Criteria::GraphRouteSearch
  def weight_of(edge)
    if edge.sailing?
      return RouteFinder::Weights::DurationWeight.new(0, 1)
    end
    return zero_weight
  end

  def zero_weight
    return RouteFinder::Weights::DurationWeight.zero
  end
end

class FakeMoneySearch < RouteFinder::Criteria::GraphRouteSearch
  COSTS = {
    "DIRC" => BigDecimal("500"),
    "LEG1" => BigDecimal("50"),
    "LEG2" => BigDecimal("50")
  }.freeze

  def weight_of(edge)
    if edge.sailing?
      return RouteFinder::Weights::MoneyWeight.new(COSTS.fetch(edge.sailing.sailing_code), 1)
    end
    return zero_weight
  end

  def zero_weight
    return RouteFinder::Weights::MoneyWeight.zero
  end
end

RSpec.describe RouteFinder::Criteria::GraphRouteSearch do
  let(:day) { Date.new(2022, 2, 1) }

  def leg_count_search(sailings)
    return LegCountSearch.new(sailings, nil)
  end

  it "returns a one-element list for a direct sailing" do
    sailings = [sailing("DIRC", "AAAAA", "BBBBB", day, day + 20)]

    route = leg_count_search(sailings).find_route("AAAAA", "BBBBB")

    expect(codes_of(route)).to eq(["DIRC"])
  end

  it "prefers the direct sailing over a two-leg alternative when the subclass counts legs" do
    sailings = [
      sailing("DIRC", "AAAAA", "BBBBB", day, day + 20),
      sailing("LEG1", "AAAAA", "CCCCC", day, day + 5),
      sailing("LEG2", "CCCCC", "BBBBB", day + 5, day + 10)
    ]

    route = leg_count_search(sailings).find_route("AAAAA", "BBBBB")

    expect(codes_of(route)).to eq(["DIRC"])
  end

  it "extracts sailing edges only, skipping the waiting edge, in path order" do
    sailings = [
      sailing("LEG1", "AAAAA", "CCCCC", day, day + 3),
      sailing("LEG2", "CCCCC", "BBBBB", day + 7, day + 10)
    ]

    route = leg_count_search(sailings).find_route("AAAAA", "BBBBB")

    expect(codes_of(route)).to eq(["LEG1", "LEG2"])
  end

  it "returns an empty list when the destination is unreachable" do
    sailings = [sailing("LEG1", "AAAAA", "CCCCC", day, day + 5)]

    expect(leg_count_search(sailings).find_route("AAAAA", "BBBBB")).to eq([])
  end

  it "returns an empty list for an empty feed" do
    expect(leg_count_search([]).find_route("AAAAA", "BBBBB")).to eq([])
  end

  it "gives a different answer on the SAME sailings once the subclass weighs edges differently" do
    sailings = [
      sailing("DIRC", "AAAAA", "BBBBB", day, day + 20),
      sailing("LEG1", "AAAAA", "CCCCC", day, day + 5),
      sailing("LEG2", "CCCCC", "BBBBB", day + 5, day + 10)
    ]

    by_leg_count = LegCountSearch.new(sailings, nil)
    by_money = FakeMoneySearch.new(sailings, nil)

    expect(codes_of(by_leg_count.find_route("AAAAA", "BBBBB"))).to eq(["DIRC"])
    expect(codes_of(by_money.find_route("AAAAA", "BBBBB"))).to eq(["LEG1", "LEG2"])
  end

  describe "the abstract methods" do
    it "raises NotImplementedError when a subclass forgets weight_of or zero_weight" do
      base = RouteFinder::Criteria::GraphRouteSearch.new([], nil)

      expect { base.zero_weight }.to raise_error(NotImplementedError)
      expect { base.weight_of(nil) }.to raise_error(NotImplementedError)
    end
  end
end
