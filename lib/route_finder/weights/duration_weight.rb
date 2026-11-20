# frozen_string_literal: true

require_relative "../errors"

module RouteFinder
  module Weights
    # Weight for fastest: (days, legs), compared by days first; legs only break ties.
    # Waiting edges carry their days too, because waiting time counts.
    class DurationWeight
      include Comparable

      attr_reader :days, :legs

      def self.zero
        return new(0, 0)
      end

      def initialize(days, legs)
        if days < 0 || legs < 0
          raise NegativeWeightError,
                "DurationWeight cannot be negative (days=#{days}, legs=#{legs})"
        end

        @days = days
        @legs = legs
        freeze
      end

      def +(other)
        return DurationWeight.new(days + other.days, legs + other.legs)
      end

      def <=>(other)
        if !other.is_a?(DurationWeight)
          return nil
        end

        return [days, legs] <=> [other.days, other.legs]
      end
    end
  end
end
