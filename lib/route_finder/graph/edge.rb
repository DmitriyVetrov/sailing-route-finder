# frozen_string_literal: true

module RouteFinder
  module Graph
    # A graph edge of one of three kinds: :sailing (carries the sailing), :waiting (stay
    # in a port until its next event) and :endpoint (from SOURCE or into SINK).
    # One class rather than a hierarchy: weighing an edge is the criteria's job.
    class Edge
      SAILING = :sailing
      WAITING = :waiting
      ENDPOINT = :endpoint

      attr_reader :from, :to, :kind, :sailing

      def self.sailing(from, to, sailing)
        return new(from, to, SAILING, sailing)
      end

      def self.waiting(from, to)
        return new(from, to, WAITING, nil)
      end

      def self.endpoint(from, to)
        return new(from, to, ENDPOINT, nil)
      end

      def initialize(from, to, kind, sailing)
        @from = from
        @to = to
        @kind = kind
        @sailing = sailing

        freeze
      end

      def sailing?
        return kind == SAILING
      end

      def waiting?
        return kind == WAITING
      end

      def endpoint?
        return kind == ENDPOINT
      end
    end
  end
end
