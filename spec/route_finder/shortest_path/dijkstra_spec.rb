# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::ShortestPath::Dijkstra do
  let(:zero) { ToyWeight.new(0) }

  def search(graph, source, target)
    dijkstra = RouteFinder::ShortestPath::Dijkstra.new(graph, ToyWeigher.new)
    return dijkstra.search(source, target, zero)
  end

  describe "the textbook graph" do
    let(:path) { search(ToyGraph.textbook, :A, :F) }

    it "finds A -> C -> B -> D -> E -> F" do
      expect(path.nodes).to eq([:A, :C, :B, :D, :E, :F])
    end

    it "costs 13" do
      expect(path.weight.value).to eq(13)
    end

    it "records the accumulated distance at every step: A0 C2 B3 D8 E10 F13" do
      distances = path.cumulative_weights.map do |weight|
        weight.value
      end

      expect(distances).to eq([0, 2, 3, 8, 10, 13])
    end

    it "returns exactly the edges between consecutive nodes" do
      pairs = path.edges.map do |edge|
        [edge.from, edge.to]
      end

      expect(pairs).to eq([[:A, :C], [:C, :B], [:B, :D], [:D, :E], [:E, :F]])
    end

    it "skips stale queue entries instead of settling a node twice" do
      expect(path.nodes).to eq([:A, :C, :B, :D, :E, :F])
      expect(path.weight.value).to eq(13)
    end
  end

  describe "other targets on the same graph" do
    it "finds the way to an intermediate node" do
      path = search(ToyGraph.textbook, :A, :D)

      expect(path.nodes).to eq([:A, :C, :B, :D])
      expect(path.weight.value).to eq(8)
    end

    it "returns a one-node path of zero weight when source equals target" do
      path = search(ToyGraph.textbook, :A, :A)

      expect(path.nodes).to eq([:A])
      expect(path.edges).to eq([])
      expect(path.weight.value).to eq(0)
    end

    it "returns nil when the target is unreachable" do
      expect(search(ToyGraph.textbook, :F, :A)).to be_nil
    end

    it "returns nil when the target is not in the graph at all" do
      expect(search(ToyGraph.textbook, :A, :Z)).to be_nil
    end
  end

  describe "collaborators" do
    it "needs nothing but edges_from and weight_of" do
      graph = double("graph")
      weigher = double("weigher")
      edge = double("edge", to: :B)

      allow(graph).to receive(:edges_from).with(:A).and_return([edge])
      allow(graph).to receive(:edges_from).with(:B).and_return([])
      allow(weigher).to receive(:weight_of).with(edge).and_return(ToyWeight.new(7))

      path = RouteFinder::ShortestPath::Dijkstra.new(graph, weigher).search(:A, :B, zero)

      expect(path.nodes).to eq([:A, :B])
      expect(path.weight.value).to eq(7)
    end
  end

  describe "tie-breaking inside the weight" do
    def triples(order)
      all = {
        direct: [:A, :D, 10],
        first_leg: [:A, :B, 5],
        second_leg: [:B, :D, 5]
      }
      return order.map do |name|
        all[name]
      end
    end

    [
      [:direct, :first_leg, :second_leg],
      [:second_leg, :first_leg, :direct],
      [:first_leg, :direct, :second_leg]
    ].each do |order|
      it "prefers the path with fewer legs regardless of edge order #{order.inspect}" do
        graph = ToyGraph.from_triples(triples(order))
        dijkstra = RouteFinder::ShortestPath::Dijkstra.new(graph, ToyMoneyWeigher.new)

        path = dijkstra.search(:A, :D, RouteFinder::Weights::MoneyWeight.zero)

        expect(path.nodes).to eq([:A, :D])
        expect(path.weight.legs).to eq(1)
      end
    end

    it "still prefers the cheaper path even if it has more legs" do
      graph = ToyGraph.from_triples([[:A, :D, 10], [:A, :B, 3], [:B, :D, 3]])
      dijkstra = RouteFinder::ShortestPath::Dijkstra.new(graph, ToyMoneyWeigher.new)

      path = dijkstra.search(:A, :D, RouteFinder::Weights::MoneyWeight.zero)

      expect(path.nodes).to eq([:A, :B, :D])
      expect(path.weight.amount).to eq(BigDecimal("6"))
    end
  end

  describe "the non-negativity precondition" do
    it "raises instead of silently returning a wrong path" do
      graph = ToyGraph.from_triples([[:A, :B, 5], [:B, :C, -3]])

      expect { search(graph, :A, :C) }.to raise_error(RouteFinder::NegativeWeightError)
    end
  end

  describe "a graph with a cycle" do
    it "ignores an edge back to a node that is already settled" do
      graph = ToyGraph.from_triples([[:A, :B, 1], [:B, :A, 1], [:B, :C, 1]])

      path = search(graph, :A, :C)

      expect(path.nodes).to eq([:A, :B, :C])
      expect(path.weight.value).to eq(2)
    end
  end
end
