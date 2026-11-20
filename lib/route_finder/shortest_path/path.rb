# frozen_string_literal: true

module RouteFinder
  module ShortestPath
    # The result of a search: the nodes, the edges between them and the accumulated weight
    # at every node. Immutable; knows nothing about sailings.
    class Path
      attr_reader :nodes, :edges, :cumulative_weights

      def initialize(nodes, edges, cumulative_weights)
        @nodes = nodes.dup.freeze
        @edges = edges.dup.freeze
        @cumulative_weights = cumulative_weights.dup.freeze
        freeze
      end

      def weight
        return cumulative_weights.last
      end
    end
  end
end
