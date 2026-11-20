# frozen_string_literal: true

module RouteFinder
  module ShortestPath
    # Min-priority queue kept as a sorted array: O(n) insert, chosen for readability.
    # Equal priorities leave in insertion order (FIFO), which keeps results deterministic.
    # No decrease-key: Dijkstra pushes a new entry and skips the stale one.
    class PriorityQueue
      class Entry
        attr_reader :item, :priority

        def initialize(item, priority)
          @item = item
          @priority = priority
        end
      end

      def initialize
        @entries = []
      end

      def empty?
        return @entries.empty?
      end

      def size
        return @entries.length
      end

      def push(item, priority)
        entry = Entry.new(item, priority)

        position = @entries.length
        while position > 0 && priority < @entries[position - 1].priority
          position -= 1
        end

        @entries.insert(position, entry)
        return nil
      end

      def pop
        return @entries.shift
      end
    end
  end
end
