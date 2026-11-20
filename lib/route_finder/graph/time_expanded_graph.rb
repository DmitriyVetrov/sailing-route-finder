# frozen_string_literal: true

require_relative "node"
require_relative "endpoint_node"
require_relative "edge"

module RouteFinder
  module Graph
    # The time-expanded event graph for one search.
    # Vertices are (port, date) events. Edges: sailings; waiting between consecutive events of
    # one port, forward only; SOURCE to every origin event and every destination event to SINK.
    # Every path is a feasible journey, so a generic Dijkstra finds the best one.
    # Same-day transfers are allowed (our assumption): an arrival and a departure on one date
    # share a vertex. A minimum connection time would need (port, date, kind) vertices.
    class TimeExpandedGraph
      NO_EDGES = [].freeze
      NO_NODES = [].freeze

      attr_reader :source, :sink

      def initialize(sailings, origin_port, destination_port)
        @origin_port = origin_port
        @destination_port = destination_port

        @source = EndpointNode.new("SOURCE")
        @sink = EndpointNode.new("SINK")

        @nodes_by_port = build_nodes_by_port(sailings)

        @edges_by_node = {}
        @edges = []

        add_sailing_edges(sailings)
        add_waiting_edges
        add_endpoint_edges
      end

      # The only method Dijkstra needs. The lookup is by value (see Node#hash).
      def edges_from(node)
        return @edges_by_node.fetch(node, NO_EDGES)
      end

      def edges
        return @edges
      end

      def ports
        return @nodes_by_port.keys.sort
      end

      def nodes_of(port)
        return @nodes_by_port.fetch(port, NO_NODES)
      end

      def nodes
        all_nodes = []
        ports.each do |port|
          all_nodes.concat(nodes_of(port))
        end
        return all_nodes
      end

      private

      def build_nodes_by_port(sailings)
        dates_by_port = {}

        sailings.each do |sailing|
          remember_date(dates_by_port, sailing.origin_port, sailing.departure_date)
          remember_date(dates_by_port, sailing.destination_port, sailing.arrival_date)
        end

        nodes_by_port = {}
        dates_by_port.each do |port, dates|
          sorted_dates = dates.uniq.sort

          nodes_by_port[port] = sorted_dates.map do |date|
            Node.new(port, date)
          end
        end

        return nodes_by_port
      end

      def remember_date(dates_by_port, port, date)
        if !dates_by_port.key?(port)
          dates_by_port[port] = []
        end
        dates_by_port[port].push(date)
      end

      def add_sailing_edges(sailings)
        sailings.each do |sailing|
          from = Node.new(sailing.origin_port, sailing.departure_date)
          to = Node.new(sailing.destination_port, sailing.arrival_date)

          add_edge(Edge.sailing(from, to, sailing))
        end
      end

      # Consecutive events only (N-1 edges per port); a longer wait chains through them.
      def add_waiting_edges
        ports.each do |port|
          nodes_of(port).each_cons(2) do |earlier, later|
            add_edge(Edge.waiting(earlier, later))
          end
        end
      end

      def add_endpoint_edges
        nodes_of(@origin_port).each do |node|
          add_edge(Edge.endpoint(@source, node))
        end

        nodes_of(@destination_port).each do |node|
          add_edge(Edge.endpoint(node, @sink))
        end
      end

      def add_edge(edge)
        if !@edges_by_node.key?(edge.from)
          @edges_by_node[edge.from] = []
        end
        @edges_by_node[edge.from].push(edge)
        @edges.push(edge)
      end
    end
  end
end
