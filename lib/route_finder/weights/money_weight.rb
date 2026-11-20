# frozen_string_literal: true

require "bigdecimal"
require_relative "../errors"

module RouteFinder
  module Weights
    # Weight for cheapest: (EUR amount, legs), compared by amount first; legs only break ties.
    # The Weight protocol Dijkstra needs is + and <=>. Every component must add up like these
    # two, or the weight stops being monotonic.
    class MoneyWeight
      include Comparable

      attr_reader :amount, :legs

      def self.zero
        return new(BigDecimal("0"), 0)
      end

      # A negative weight would break Dijkstra, so it cannot be created.
      def initialize(amount, legs)
        if amount < 0 || legs < 0
          raise NegativeWeightError,
                "MoneyWeight cannot be negative (amount=#{amount}, legs=#{legs})"
        end

        @amount = amount
        @legs = legs

        freeze
      end

      def +(other)
        return MoneyWeight.new(amount + other.amount, legs + other.legs)
      end

      def <=>(other)
        if !other.is_a?(MoneyWeight)
          return nil
        end

        return [amount, legs] <=> [other.amount, other.legs]
      end
    end
  end
end
