# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Money do
  describe ".from_text" do
    it "keeps the original text exactly as it came from the feed" do
      money = usd("589.30")

      expect(money.original_text).to eq("589.30")
      expect(money.currency).to eq("USD")
    end

    it "parses the text into an exact BigDecimal, not a Float" do
      money = usd("589.30")

      expect(money.amount).to be_a(BigDecimal)
      expect(money.amount).to eq(BigDecimal("589.30"))
    end

    it "does not lose the trailing zero that BigDecimal itself forgets" do
      money = usd("589.30")

      expect(money.amount.to_s("F")).to eq("589.3")
      expect(money.original_text).to eq("589.30")
    end

    it "rejects text that is not a number" do
      expect { usd("abc") }.to raise_error(ArgumentError)
    end
  end

  describe "comparison" do
    it "orders amounts in the same currency" do
      expect(usd("10.00")).to be < usd("10.01")
      expect(usd("20")).to be > usd("19.99")
    end

    it "compares unrounded amounts" do
      small = RouteFinder::Money.new(BigDecimal("1.0000001"), "EUR")
      large = RouteFinder::Money.new(BigDecimal("1.0000002"), "EUR")

      expect(small).to be < large
    end

    it "raises a clear error when currencies differ" do
      eur = RouteFinder::Money.new(BigDecimal("10"), "EUR")

      expect { usd("10") < eur }.to raise_error(
        RouteFinder::CurrencyMismatchError, /USD.*EUR/
      )
    end

    it "does not pick a maximum across currencies" do
      eur = RouteFinder::Money.new(BigDecimal("10"), "EUR")

      expect { [usd("10"), eur].max }.to raise_error(RouteFinder::CurrencyMismatchError)
    end

    it "is not comparable with something that is not Money" do
      expect(usd("10") <=> 10).to be_nil
    end
  end

  describe "equality" do
    it "treats the same amount and currency as equal, ignoring the original text" do
      expect(usd("589.3")).to eq(usd("589.30"))
    end

    it "is false, not an error, for different currencies" do
      eur = RouteFinder::Money.new(BigDecimal("10"), "EUR")

      expect(usd("10")).not_to eq(eur)
    end

    it "is false for objects that are not Money" do
      expect(usd("10")).not_to eq("10")
    end
  end

  describe "immutability" do
    it "cannot be changed after creation" do
      money = usd("10")

      expect(money).to be_frozen
      expect { money.instance_variable_set(:@currency, "EUR") }.to raise_error(FrozenError)
    end
  end

  describe "#to_display_string" do
    it "rounds half up to two decimals" do
      expect(RouteFinder::Money.new(BigDecimal("0.125"), "EUR").to_display_string).to eq("0.13")
      expect(RouteFinder::Money.new(BigDecimal("0.124"), "EUR").to_display_string).to eq("0.12")
    end

    it "keeps the trailing zero" do
      expect(RouteFinder::Money.new(BigDecimal("61.8"), "EUR").to_display_string).to eq("61.80")
    end

    it "adds the decimals to whole amounts" do
      expect(RouteFinder::Money.new(BigDecimal("97453"), "JPY").to_display_string).to eq("97453.00")
    end

    it "does not use scientific notation" do
      expect(RouteFinder::Money.new(BigDecimal("729.0357"), "EUR").to_display_string).to eq("729.04")
    end
  end
end
