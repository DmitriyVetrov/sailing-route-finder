# frozen_string_literal: true

module RouteFinder
  module Feed
    module RateResolvers
      # Duplicate-rate policy: the highest rate wins (confirmed by the PO for MNOP).
      # A policy object (Strategy): another rule is a new class, RateBook stays as it is.
      # Contract of every resolver: resolve(non-empty array of Money) returns one of them.
      class HighestRate
        def resolve(candidates)
          return candidates.max
        end
      end
    end
  end
end
