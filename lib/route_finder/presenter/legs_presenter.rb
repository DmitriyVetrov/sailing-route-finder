# frozen_string_literal: true

require "json"

module RouteFinder
  module Presenter
    # Renders a route as the README's JSON array. The rate is echoed exactly as the feed
    # has it, so the presenter reads it from RateBook rather than using the EUR cost.
    class LegsPresenter
      def initialize(rate_book)
        @rate_book = rate_book
      end

      def render(sailings)
        legs = sailings.map do |sailing|
          build_leg(sailing)
        end

        # pretty_generate([]) prints "[\n\n]" with this json version; the expected shape is "[]".
        if legs.empty?
          return "[]"
        end

        return JSON.pretty_generate(legs)
      end

      private

      def build_leg(sailing)
        rate = @rate_book.rate_for(sailing.sailing_code)

        leg = {
          "origin_port" => sailing.origin_port,
          "destination_port" => sailing.destination_port,
          "departure_date" => sailing.departure_date.iso8601,
          "arrival_date" => sailing.arrival_date.iso8601,
          "sailing_code" => sailing.sailing_code,
          "rate" => rate.original_text,
          "rate_currency" => rate.currency
        }
        return leg
      end
    end
  end
end
