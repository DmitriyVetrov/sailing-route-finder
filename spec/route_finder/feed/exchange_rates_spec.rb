# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Feed::ExchangeRates do
  let(:date) { Date.new(2022, 2, 1) }

  let(:rates) do
    RouteFinder::Feed::ExchangeRates.new(
      date => { "USD" => BigDecimal("1.126"), "JPY" => BigDecimal("130.15") }
    )
  end

  describe "#to_eur" do
    it "divides by the rate of the given day" do
      eur = rates.to_eur(money("589.30", "USD"), date)

      # 589.30 / 1.126 = 523.3570159...
      expect(eur.currency).to eq("EUR")
      expect(eur.to_display_string).to eq("523.36")
    end

    it "does not round the stored amount, only the displayed one" do
      eur = rates.to_eur(money("589.30", "USD"), date)

      expect(eur.amount).to be > BigDecimal("523.357")
      expect(eur.amount).to be < BigDecimal("523.358")
    end

    it "works for currencies with large rates" do
      eur = rates.to_eur(money("97453", "JPY"), date)

      # 97453 / 130.15 = 748.7744...
      expect(eur.to_display_string).to eq("748.77")
    end

    it "returns EUR money unchanged and does not need a rate for that day" do
      euros = money("761.96", "EUR")
      rates_without_that_day = RouteFinder::Feed::ExchangeRates.new({})

      expect(rates_without_that_day.to_eur(euros, date)).to equal(euros)
    end

    it "drops the original text, because the result is our calculation" do
      eur = rates.to_eur(money("589.30", "USD"), date)

      expect(eur.original_text).to be_nil
    end

    it "does not change the money it was given" do
      usd = money("589.30", "USD")
      rates.to_eur(usd, date)

      expect(usd.currency).to eq("USD")
      expect(usd.original_text).to eq("589.30")
    end

    it "raises a clear error when there are no rates for the date" do
      other_day = Date.new(2022, 2, 3)

      expect { rates.to_eur(money("10", "USD"), other_day) }.to raise_error(
        RouteFinder::ExchangeRateNotFoundError, /2022-02-03/
      )
    end

    it "raises a clear error when the currency is missing on that date" do
      expect { rates.to_eur(money("10", "GBP"), date) }.to raise_error(
        RouteFinder::ExchangeRateNotFoundError, /GBP.*2022-02-01/
      )
    end
  end

  describe "#eur_rate" do
    it "returns the rate as BigDecimal" do
      expect(rates.eur_rate("USD", date)).to eq(BigDecimal("1.126"))
    end
  end

  describe "#convertible?" do
    it "is true when the date has a rate for the currency" do
      expect(rates.convertible?("USD", date)).to be(true)
    end

    it "is true for EUR on any date, because EUR needs no rate" do
      expect(rates.convertible?("EUR", Date.new(1999, 1, 1))).to be(true)
    end

    it "is false when the date has no rates" do
      expect(rates.convertible?("USD", Date.new(2022, 2, 3))).to be(false)
    end

    it "is false when the date has no rate for the currency" do
      expect(rates.convertible?("GBP", date)).to be(false)
    end
  end
end
