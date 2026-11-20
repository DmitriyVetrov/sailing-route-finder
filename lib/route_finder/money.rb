# frozen_string_literal: true

require "bigdecimal"
require_relative "errors"

module RouteFinder
  # An amount and its currency, immutable. Comparison never mixes currencies silently.
  # original_text keeps the feed's exact string ("589.30"): BigDecimal forgets the trailing
  # zero, and the output must echo the rate verbatim.
  class Money
    include Comparable

    DISPLAY_DECIMALS = 2

    attr_reader :amount, :currency, :original_text

    def self.from_text(text, currency)
      amount = BigDecimal(text)
      return new(amount, currency, text)
    end

    def initialize(amount, currency, original_text = nil)
      @amount = amount
      @currency = currency
      @original_text = original_text

      freeze
    end

    # Comparing different currencies is a programming error, not "incomparable".
    def <=>(other)
      if !other.is_a?(Money)
        return nil
      end

      if currency != other.currency
        raise CurrencyMismatchError,
              "Cannot compare #{currency} with #{other.currency} without conversion"
      end

      return amount <=> other.amount
    end

    # Separate from <=>, so that USD == EUR is false instead of raising. The original text
    # is not part of equality. Money is never a Hash key, so hash/eql? are not needed.
    def ==(other)
      if !other.is_a?(Money)
        return false
      end

      return currency == other.currency && amount == other.amount
    end

    # Half-up to two decimals with trailing zeros ("61.80"); for display only.
    def to_display_string
      rounded = amount.round(DISPLAY_DECIMALS, :half_up)
      text = rounded.to_s("F")
      parts = text.split(".")
      integer_part = parts[0]
      fraction_part = parts[1]
      padded_fraction = fraction_part.ljust(DISPLAY_DECIMALS, "0")
      return "#{integer_part}.#{padded_fraction}"
    end
  end
end
