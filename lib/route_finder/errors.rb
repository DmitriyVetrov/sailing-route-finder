# frozen_string_literal: true

# All application errors share one base class, so the CLI can rescue "any error of ours"
# without also hiding real bugs such as NoMethodError.
module RouteFinder
  class Error < StandardError; end

  # Two amounts in different currencies were compared without conversion.
  class CurrencyMismatchError < Error; end

  # No exchange rate for the requested currency and date.
  class ExchangeRateNotFoundError < Error; end

  # No rate for the requested sailing code.
  class RateNotFoundError < Error; end

  # A weight with a negative component was given to Dijkstra.
  class NegativeWeightError < Error; end

  # The criteria line names a criteria that is not registered.
  class UnknownCriteriaError < Error; end

  # The three input lines do not form a valid search.
  class InvalidInputError < Error; end
end
