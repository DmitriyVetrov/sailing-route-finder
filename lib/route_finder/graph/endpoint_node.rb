# frozen_string_literal: true

module RouteFinder
  module Graph
    # The artificial SOURCE or SINK, so Dijkstra has one start and one finish.
    # Identity equality is enough: each exists exactly once per graph.
    class EndpointNode
      attr_reader :label

      def initialize(label)
        @label = label
        freeze
      end

      def to_s
        return label
      end
    end
  end
end
