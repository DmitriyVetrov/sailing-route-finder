# frozen_string_literal: true

require "date"

module RouteFinder
  module Graph
    # An event vertex: being in `port` on `date`. Time lives in the vertex, so "the ship
    # left before you arrived" is a missing edge rather than a check in the search.
    # A value object: the same port and date are the same Hash or Set key.
    class Node
      attr_reader :port, :date

      def initialize(port, date)
        @port = port
        @date = date

        freeze
      end

      # hash, eql? and == agree, so a Node rebuilt from the same values finds the same entry.
      # Comparable alone would not do: it defines == but neither hash nor eql?.
      def hash
        return [port, date].hash
      end

      def eql?(other)
        if !other.is_a?(Node)
          return false
        end
        return port == other.port && date == other.date
      end

      def ==(other)
        return eql?(other)
      end

      def to_s
        return "(#{port}, #{date})"
      end
    end
  end
end
