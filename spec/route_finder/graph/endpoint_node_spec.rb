# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Graph::EndpointNode do
  it "prints its label" do
    expect(RouteFinder::Graph::EndpointNode.new("SOURCE").to_s).to eq("SOURCE")
  end

  it "is identified by object identity, not by label" do
    first = RouteFinder::Graph::EndpointNode.new("SOURCE")
    second = RouteFinder::Graph::EndpointNode.new("SOURCE")

    expect(first).to eq(first)
    expect(first).not_to eq(second)
  end
end
