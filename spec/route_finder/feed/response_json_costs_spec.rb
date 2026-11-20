# frozen_string_literal: true

require "spec_helper"

# The EUR cost table of docs/PLAN.md (phase 2), also printed by bin/debug/cost_table.
RSpec.describe "EUR costs of the sample feed (response.json)" do
  expected_rows = [
    ["ABCD", "CNSHA", "NLRTM", "2022-02-01", "2022-03-01", 28, "523.36"],
    ["EFGH", "CNSHA", "NLRTM", "2022-02-02", "2022-03-02", 28, "890.32"],
    ["IJKL", "CNSHA", "NLRTM", "2022-01-31", "2022-02-28", 28, "742.78"],
    ["MNOP", "CNSHA", "NLRTM", "2022-01-30", "2022-03-05", 34, "729.04"],
    ["QRST", "CNSHA", "NLRTM", "2022-01-29", "2022-02-15", 17, "761.96"],
    ["ERXQ", "CNSHA", "ESBCN", "2022-01-29", "2022-02-12", 14, "261.96"],
    ["ETRF", "ESBCN", "NLRTM", "2022-02-15", "2022-03-29", 42, "61.80"],
    ["ETRG", "ESBCN", "NLRTM", "2022-02-16", "2022-02-20", 4, "60.93"],
    ["ETRB", "ESBCN", "BRSSZ", "2022-02-16", "2022-03-14", 26, "383.17"]
  ]

  let(:loader) { load_sample_feed }

  let(:lowest_loader) { load_feed(sample_feed_path, LowestRateResolver.new) }

  def sailing_with_code(a_loader, code)
    return a_loader.sailings.find do |sailing|
      sailing.sailing_code == code
    end
  end

  def eur_cost_of(code, a_loader = loader)
    sailing = sailing_with_code(a_loader, code)
    return cost_calculator_for(a_loader).cost_of(sailing)
  end

  it "contains exactly the nine sailings of the table" do
    codes = loader.sailings.map do |sailing|
      sailing.sailing_code
    end

    expect(codes).to eq(expected_rows.map { |row| row[0] })
  end

  expected_rows.each do |row|
    code, origin, destination, departure, arrival, days, eur = row

    it "#{code}: #{origin} -> #{destination}, #{days} days, #{eur} EUR" do
      sailing = sailing_with_code(loader, code)

      expect(sailing.origin_port).to eq(origin)
      expect(sailing.destination_port).to eq(destination)
      expect(sailing.departure_date.iso8601).to eq(departure)
      expect(sailing.arrival_date.iso8601).to eq(arrival)
      expect(sailing.duration_days).to eq(days)
      expect(eur_cost_of(code).to_display_string).to eq(eur)
    end
  end

  describe "the original rate survives untouched (the output echoes it verbatim)" do
    it "keeps the string and currency of a USD rate" do
      rate = loader.rate_book.rate_for("ABCD")

      expect(rate.original_text).to eq("589.30")
      expect(rate.currency).to eq("USD")
    end

    it "keeps a JPY rate without inventing decimals" do
      rate = loader.rate_book.rate_for("IJKL")

      expect(rate.original_text).to eq("97453")
      expect(rate.currency).to eq("JPY")
    end

    it "keeps a EUR rate as it is" do
      rate = loader.rate_book.rate_for("QRST")

      expect(rate.original_text).to eq("761.96")
      expect(rate.currency).to eq("EUR")
    end
  end

  describe "the duplicate MNOP rate (456.78 and 812.00 USD in the feed)" do
    it "resolves to the higher one with HighestRate: 812.00 USD = 729.04 EUR" do
      rate = loader.rate_book.rate_for("MNOP")

      expect(rate.original_text).to eq("812.00")
      expect(eur_cost_of("MNOP").to_display_string).to eq("729.04")
    end

    it "would resolve to the lower one under a lowest-rate policy: 410.11 EUR" do
      rate = lowest_loader.rate_book.rate_for("MNOP")

      expect(rate.original_text).to eq("456.78")
      expect(eur_cost_of("MNOP", lowest_loader).to_display_string).to eq("410.11")
    end
  end

  describe "the effect of the duplicate rule on the cheapest direct sailing" do
    it "makes ABCD (523.36) cheaper than MNOP (729.04)" do
      expect(eur_cost_of("ABCD")).to be < eur_cost_of("MNOP")
    end

    it "would make MNOP (410.11) cheaper than ABCD under a lowest-rate policy" do
      expect(eur_cost_of("MNOP", lowest_loader)).to be < eur_cost_of("ABCD")
    end
  end
end
