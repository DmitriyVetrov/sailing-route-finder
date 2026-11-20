# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::ShortestPath::Path do
  it "reports the weight of the last node as the total" do
    path = RouteFinder::ShortestPath::Path.new([:A, :B], [:edge], [1, 5])

    expect(path.weight).to eq(5)
  end

  it "is immutable and does not share arrays with the caller" do
    nodes = [:A, :B]
    path = RouteFinder::ShortestPath::Path.new(nodes, [:edge], [1, 5])

    nodes << :C

    expect(path.nodes).to eq([:A, :B])
    expect(path.nodes).to be_frozen
    expect(path.edges).to be_frozen
    expect(path.cumulative_weights).to be_frozen
    expect(path).to be_frozen
  end
end
