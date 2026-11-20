# frozen_string_literal: true

require_relative "../graph/time_expanded_graph"
require_relative "../shortest_path/dijkstra"

module RouteFinder
  module Criteria
    # Base class for criteria that search the time-expanded graph (Template Method):
    # find_route builds the graph, runs Dijkstra and maps the path back to sailings;
    # a subclass defines only weight_of(edge) and zero_weight.
    class GraphRouteSearch
      def initialize(sailings, cost_calculator)
        @sailings = sailings

        @cost_calculator = cost_calculator
      end

      def find_route(origin_port, destination_port)
        graph = Graph::TimeExpandedGraph.new(@sailings, origin_port, destination_port)

        # The criteria itself is the weigher Dijkstra calls.
        dijkstra = ShortestPath::Dijkstra.new(graph, self)

        path = dijkstra.search(graph.source, graph.sink, zero_weight)

        if path.nil?
          return []
        end

        return sailings_from(path)
      end

      # Abstract. Public because Dijkstra calls it.
      def weight_of(edge)
        raise NotImplementedError, "#{self.class} must implement weight_of(edge)"
      end

      # Abstract: the weight of an empty path, of the same type as weight_of.
      def zero_weight
        raise NotImplementedError, "#{self.class} must implement zero_weight"
      end

      private

      # The path also holds waiting and SOURCE/SINK edges; only sailings are returned, in order.
      def sailings_from(path)
        sailings = []

        path.edges.each do |edge|
          if edge.sailing?
            sailings.push(edge.sailing)
          end
        end

        return sailings
      end
    end
  end
end
