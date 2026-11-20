# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Graph::TimeExpandedGraph do
  let(:sailings) { load_sample_feed.sailings }
  let(:graph) { RouteFinder::Graph::TimeExpandedGraph.new(sailings, "CNSHA", "NLRTM") }

  def node(port, month, day)
    return RouteFinder::Graph::Node.new(port, Date.new(2022, month, day))
  end

  def sailing_edges_from(a_graph, a_node)
    result = []
    a_graph.edges_from(a_node).each do |edge|
      if edge.sailing?
        result.push(edge)
      end
    end
    return result
  end

  def waiting_edges_from(a_graph, a_node)
    result = []
    a_graph.edges_from(a_node).each do |edge|
      if edge.waiting?
        result.push(edge)
      end
    end
    return result
  end

  def acyclic?(a_graph)
    all_nodes = a_graph.nodes + [a_graph.source, a_graph.sink]

    incoming = {}
    all_nodes.each do |a_node|
      incoming[a_node] = 0
    end
    a_graph.edges.each do |edge|
      incoming[edge.to] += 1
    end

    ready = []
    all_nodes.each do |a_node|
      if incoming[a_node] == 0
        ready.push(a_node)
      end
    end

    removed = 0
    while !ready.empty?
      current = ready.pop
      removed += 1

      a_graph.edges_from(current).each do |edge|
        incoming[edge.to] -= 1
        if incoming[edge.to] == 0
          ready.push(edge.to)
        end
      end
    end

    return removed == all_nodes.length
  end

  describe "on response.json" do
    it "has one event node per distinct (port, date) of departures and arrivals" do
      expect(graph.nodes.length).to eq(16)
      expect(graph.ports).to eq(%w[BRSSZ CNSHA ESBCN NLRTM])
      expect(graph.nodes_of("CNSHA").length).to eq(5)
      expect(graph.nodes_of("ESBCN").length).to eq(3)
      expect(graph.nodes_of("NLRTM").length).to eq(7)
      expect(graph.nodes_of("BRSSZ").length).to eq(1)
    end

    it "lists the nodes of a port in date order" do
      dates = graph.nodes_of("ESBCN").map { |a_node| a_node.date.to_s }

      expect(dates).to eq(%w[2022-02-12 2022-02-15 2022-02-16])
    end

    it "has a sailing edge per sailing, between the right event nodes" do
      edges = sailing_edges_from(graph, node("CNSHA", 1, 29))
      codes = edges.map { |edge| edge.sailing.sailing_code }

      expect(codes.sort).to eq(["ERXQ", "QRST"])

      erxq = edges.find { |edge| edge.sailing.sailing_code == "ERXQ" }
      expect(erxq.to).to eq(node("ESBCN", 2, 12))
    end

    it "contains the chain ERXQ -> wait -> wait -> ETRG" do
      after_erxq = sailing_edges_from(graph, node("CNSHA", 1, 29)).find do |edge|
        edge.sailing.sailing_code == "ERXQ"
      end
      arrived = after_erxq.to
      expect(arrived).to eq(node("ESBCN", 2, 12))

      first_wait = waiting_edges_from(graph, arrived).first
      expect(first_wait.to).to eq(node("ESBCN", 2, 15))

      second_wait = waiting_edges_from(graph, first_wait.to).first
      expect(second_wait.to).to eq(node("ESBCN", 2, 16))

      codes = sailing_edges_from(graph, second_wait.to).map { |edge| edge.sailing.sailing_code }
      expect(codes.sort).to eq(["ETRB", "ETRG"])
    end

    it "has no edge from the ERXQ arrival straight into a sailing that left earlier" do
      expect(sailing_edges_from(graph, node("ESBCN", 2, 12))).to be_empty
      expect(waiting_edges_from(graph, node("ESBCN", 2, 12)).map { |edge| edge.to.date.to_s })
        .to eq(["2022-02-15"])
    end

    it "chains waiting edges only between consecutive events, forward in time" do
      waits = graph.edges.select { |edge| edge.waiting? }

      expect(waits.length).to eq(12)
      waits.each do |edge|
        expect(edge.from.port).to eq(edge.to.port)
        expect(edge.to.date).to be > edge.from.date
      end
    end

    it "never has an edge that goes backwards (or sideways) in time" do
      real_edges = graph.edges.select { |edge| !edge.endpoint? }

      expect(real_edges.length).to eq(21)
      real_edges.each do |edge|
        expect(edge.to.date).to be > edge.from.date
      end
    end

    it "is acyclic" do
      expect(acyclic?(graph)).to be(true)
    end

    it "wires the source to every event of the origin port only" do
      targets = graph.edges_from(graph.source).map { |edge| edge.to }

      expect(targets).to eq(graph.nodes_of("CNSHA"))
      graph.edges_from(graph.source).each do |edge|
        expect(edge.endpoint?).to be(true)
      end
    end

    it "wires every event of the destination port to the sink only" do
      sink_edges = graph.edges.select { |edge| edge.to == graph.sink }
      sources = sink_edges.map { |edge| edge.from }

      expect(sources).to eq(graph.nodes_of("NLRTM"))
    end

    it "has 33 edges in total: 9 sailings, 12 waits, 5 from source, 7 to sink" do
      expect(graph.edges.length).to eq(33)
    end

    it "gives nodes without outgoing edges an empty list" do
      expect(graph.edges_from(node("BRSSZ", 3, 14))).to be_empty
      expect(graph.edges_from(graph.sink)).to be_empty
      expect(graph.edges_from(node("XXXXX", 1, 1))).to be_empty
    end

    it "finds edges for a node built independently (value equality)" do
      expect(graph.edges_from(node("CNSHA", 1, 29)).length).to eq(3)
    end
  end

  describe "same-day transfer assumption" do
    it "lets a ship that arrives on a given day be followed by one leaving that same day" do
      feb_1 = Date.new(2022, 2, 1)
      feb_5 = Date.new(2022, 2, 5)
      feb_9 = Date.new(2022, 2, 9)
      synthetic = [
        sailing("S1", "AAAAA", "BBBBB", feb_1, feb_5),
        sailing("S2", "BBBBB", "CCCCC", feb_5, feb_9)
      ]
      small = RouteFinder::Graph::TimeExpandedGraph.new(synthetic, "AAAAA", "CCCCC")

      joint = RouteFinder::Graph::Node.new("BBBBB", feb_5)
      leaving = sailing_edges_from(small, joint).map { |edge| edge.sailing.sailing_code }

      expect(leaving).to eq(["S2"])
    end
  end

  describe "a sailing that does not respect time" do
    it "makes the acyclicity check fail, so that check is not vacuous" do
      feb_5 = Date.new(2022, 2, 5)
      feb_10 = Date.new(2022, 2, 10)
      broken = [
        sailing("X", "AAAAA", "BBBBB", feb_10, feb_5),
        sailing("Y", "BBBBB", "AAAAA", feb_5, feb_10)
      ]
      bad_graph = RouteFinder::Graph::TimeExpandedGraph.new(broken, "AAAAA", "BBBBB")

      expect(acyclic?(bad_graph)).to be(false)
    end
  end

  describe "queries that cannot be answered" do
    it "has no source edges for an unknown origin port" do
      unknown = RouteFinder::Graph::TimeExpandedGraph.new(sailings, "ZZZZZ", "NLRTM")

      expect(unknown.edges_from(unknown.source)).to be_empty
      expect(unknown.nodes_of("ZZZZZ")).to be_empty
    end

    it "builds an empty graph from an empty feed" do
      empty = RouteFinder::Graph::TimeExpandedGraph.new([], "CNSHA", "NLRTM")

      expect(empty.nodes).to be_empty
      expect(empty.edges).to be_empty
    end
  end
end
