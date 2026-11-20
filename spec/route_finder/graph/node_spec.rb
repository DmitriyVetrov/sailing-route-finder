# frozen_string_literal: true

require "spec_helper"

class ComparableOnly
  include Comparable

  attr_reader :value

  def initialize(value)
    @value = value
  end

  def <=>(other)
    return value <=> other.value
  end
end

RSpec.describe RouteFinder::Graph::Node do
  let(:feb_12) { Date.new(2022, 2, 12) }

  it "exposes its port and date" do
    node = RouteFinder::Graph::Node.new("ESBCN", feb_12)

    expect(node.port).to eq("ESBCN")
    expect(node.date).to eq(feb_12)
  end

  it "is immutable" do
    expect(RouteFinder::Graph::Node.new("ESBCN", feb_12)).to be_frozen
  end

  it "prints as (port, date)" do
    expect(RouteFinder::Graph::Node.new("ESBCN", feb_12).to_s).to eq("(ESBCN, 2022-02-12)")
  end

  describe "equality by value" do
    let(:first) { RouteFinder::Graph::Node.new("ESBCN", feb_12) }
    let(:second) { RouteFinder::Graph::Node.new("ESBCN", Date.new(2022, 2, 12)) }

    it "treats equal port and date as the same node" do
      expect(first).not_to equal(second)
      expect(first).to eq(second)
      expect(first).to eql(second)
      expect(first.hash).to eq(second.hash)
    end

    it "tells nodes apart when the port or the date differ" do
      expect(first).not_to eq(RouteFinder::Graph::Node.new("NLRTM", feb_12))
      expect(first).not_to eq(RouteFinder::Graph::Node.new("ESBCN", Date.new(2022, 2, 13)))
      expect(first).not_to eql(RouteFinder::Graph::Node.new("ESBCN", Date.new(2022, 2, 13)))
    end

    it "is never equal to something that is not a node" do
      expect(first).not_to eq("ESBCN")
      expect(first).not_to eq(nil)
      expect(first.eql?(42)).to be(false)
    end

    it "works as a Hash key: a freshly built equal node finds the stored value" do
      distances = { first => 7 }

      expect(distances[second]).to eq(7)
      expect(distances.key?(second)).to be(true)
    end

    it "is deduplicated by Set and uniq" do
      expect(Set.new([first, second]).length).to eq(1)
      expect([first, second].uniq.length).to eq(1)
    end
  end

  describe "why Comparable alone is not enough" do
    it "gives == but not a usable Hash key" do
      a = ComparableOnly.new(1)
      b = ComparableOnly.new(1)

      expect(a == b).to be(true)
      expect({ a => "found" }[b]).to be_nil
    end
  end
end
