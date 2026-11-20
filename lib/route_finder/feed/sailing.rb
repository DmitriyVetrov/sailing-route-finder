# frozen_string_literal: true

require "date"

module RouteFinder
  module Feed
    # One scheduled sailing, immutable. It deliberately has no price: rates come from a
    # separate feed array, can be duplicated or missing, and are looked up in RateBook.
    class Sailing
      attr_reader :origin_port, :destination_port, :departure_date, :arrival_date, :sailing_code

      def initialize(origin_port, destination_port, departure_date, arrival_date, sailing_code)
        @origin_port = origin_port
        @destination_port = destination_port
        @departure_date = departure_date
        @arrival_date = arrival_date
        @sailing_code = sailing_code

        freeze
      end

      # Whole days: the feed has dates only.
      def duration_days
        difference = arrival_date - departure_date
        return difference.to_i
      end
    end
  end
end
