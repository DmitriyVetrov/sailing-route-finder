# frozen_string_literal: true

require "set"
require_relative "../errors"
require_relative "priority_queue"
require_relative "path"

# Dijkstra's algorithm, generic over the graph and the weight type.
# Preconditions: weights are non-negative (checked here: NegativeWeightError) and the
# weight type is monotonic, a <= b implies a + c <= b + c (checked by the weight contract
# spec). Nothing here knows about ports, sailings, dates or money.
module RouteFinder
  module ShortestPath
    # Collaborators: graph.edges_from(node) and weigher.weight_of(edge); an edge answers `to`,
    # a weight answers + and <=> (with Comparable).
    class Dijkstra
      def initialize(graph, weigher)
        @graph = graph
        @weigher = weigher
      end

      def search(source, target, zero)
        distances = { source => zero }

        previous_nodes = {}
        previous_edges = {}

        settled = Set.new

        queue = PriorityQueue.new
        queue.push(source, zero)

        while !queue.empty?
          entry = queue.pop
          node = entry.item

          # Lazy deletion: a stale queue entry for an already settled node is skipped.
          if settled.include?(node)
            next
          end
          settled.add(node)

          if node == target
            return build_path(source, target, distances, previous_nodes, previous_edges)
          end

          @graph.edges_from(node).each do |edge|
            neighbour = edge.to
            if settled.include?(neighbour)
              next
            end

            edge_weight = @weigher.weight_of(edge)
            if edge_weight < zero
              raise NegativeWeightError,
                    "Dijkstra requires non-negative weights, got #{edge_weight.inspect}"
            end

            candidate = distances[node] + edge_weight
            known = distances[neighbour]

            # Strictly better only: ties keep the first path found, so tie-breaking lives in the
            # weight type. There is no decrease-key; a new entry is pushed instead.
            if known.nil? || candidate < known
              distances[neighbour] = candidate
              previous_nodes[neighbour] = node
              previous_edges[neighbour] = edge

              queue.push(neighbour, candidate)
            end
          end
        end

        return nil
      end

      private

      def build_path(source, target, distances, previous_nodes, previous_edges)
        nodes = [target]
        edges = []
        weights = [distances[target]]

        current = target
        while current != source
          edge = previous_edges[current]
          current = previous_nodes[current]

          edges.unshift(edge)
          nodes.unshift(current)
          weights.unshift(distances[current])
        end

        return Path.new(nodes, edges, weights)
      end
    end
  end
end
