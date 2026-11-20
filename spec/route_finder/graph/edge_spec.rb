# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Graph::Edge do
  let(:from) { RouteFinder::Graph::Node.new("CNSHA", Date.new(2022, 1, 29)) }
  let(:to) { RouteFinder::Graph::Node.new("ESBCN", Date.new(2022, 2, 12)) }
  let(:erxq) { sailing("ERXQ", "CNSHA", "ESBCN", Date.new(2022, 1, 29), Date.new(2022, 2, 12)) }

  it "builds a sailing edge that carries its sailing" do
    edge = RouteFinder::Graph::Edge.sailing(from, to, erxq)

    expect(edge.from).to eq(from)
    expect(edge.to).to eq(to)
    expect(edge.sailing).to be(erxq)
    expect(edge.sailing?).to be(true)
    expect(edge.waiting?).to be(false)
    expect(edge.endpoint?).to be(false)
  end

  it "builds a waiting edge without a sailing" do
    edge = RouteFinder::Graph::Edge.waiting(from, to)

    expect(edge.sailing).to be_nil
    expect(edge.waiting?).to be(true)
    expect(edge.sailing?).to be(false)
  end

  it "builds an endpoint edge without a sailing" do
    edge = RouteFinder::Graph::Edge.endpoint(from, to)

    expect(edge.sailing).to be_nil
    expect(edge.endpoint?).to be(true)
    expect(edge.waiting?).to be(false)
  end

  it "is immutable" do
    expect(RouteFinder::Graph::Edge.waiting(from, to)).to be_frozen
  end
end
