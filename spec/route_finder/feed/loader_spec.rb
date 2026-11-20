# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RouteFinder::Feed::Loader do
  let(:highest) { highest_rate }

  # A small clean feed: one USD sailing, two duplicate rates, one exchange rate.
  let(:feed) do
    {
      "sailings" => [
        { "origin_port" => "AAAAA", "destination_port" => "BBBBB",
          "departure_date" => "2022-02-01", "arrival_date" => "2022-02-11",
          "sailing_code" => "S001" }
      ],
      "rates" => [
        { "sailing_code" => "S001", "rate" => "10.50", "rate_currency" => "USD" },
        { "sailing_code" => "S001", "rate" => "20.00", "rate_currency" => "USD" }
      ],
      "exchange_rates" => {
        "2022-02-01" => { "usd" => 1.5 }
      }
    }
  end

  let(:logger_and_output) { capturing_logger }
  let(:log) { logger_and_output[1] }

  def load(document)
    return load_text(JSON.generate(document))
  end

  def load_text(json_text)
    return RouteFinder::Feed::Loader.new(json_text, highest, logger_and_output[0])
  end

  # The feed with the first sailing's fields replaced (nil removes a field).
  def with_sailing(changes)
    document = JSON.parse(JSON.generate(feed))
    changes.each do |field, value|
      if value.nil?
        document["sailings"][0].delete(field)
      else
        document["sailings"][0][field] = value
      end
    end
    return document
  end

  describe "a clean feed" do
    let(:loader) { load(feed) }

    it "turns the sailings array into Sailing objects with real dates" do
      sailing = loader.sailings.first

      expect(loader.sailings.length).to eq(1)
      expect(sailing).to be_a(RouteFinder::Feed::Sailing)
      expect(sailing.origin_port).to eq("AAAAA")
      expect(sailing.departure_date).to eq(Date.new(2022, 2, 1))
      expect(sailing.duration_days).to eq(10)
    end

    it "groups duplicate rates and resolves them through the injected resolver" do
      expect(loader.rate_book.rate_for("S001").original_text).to eq("20.00")
    end

    it "uses the resolver it was given" do
      lowest_loader = RouteFinder::Feed::Loader.new(JSON.generate(feed), LowestRateResolver.new, silent_logger)

      expect(lowest_loader.rate_book.rate_for("S001").original_text).to eq("10.50")
    end

    it "reads exchange rates with upper-case currencies and exact decimals" do
      rate = loader.exchange_rates.eur_rate("USD", Date.new(2022, 2, 1))

      expect(rate).to be_a(BigDecimal)
      expect(rate).to eq(BigDecimal("1.5"))
    end

    it "logs nothing" do
      loader

      expect(log.string).to be_empty
    end
  end

  describe "exchange rate precision" do
    it "does not pass exchange rates through Float" do
      text = JSON.generate(feed).sub("1.5", "1.1138")
      rate = load_text(text).exchange_rates.eur_rate("USD", Date.new(2022, 2, 1))

      # As a Float 1.1138 would be 1.1137999999999999...
      expect(rate.to_s("F")).to eq("1.1138")
    end

    it "accepts an integer exchange rate" do
      text = JSON.generate(feed).sub("1.5", "2")

      expect(load_text(text).exchange_rates.eur_rate("USD", Date.new(2022, 2, 1))).to eq(BigDecimal("2"))
    end
  end

  describe "a broken document becomes an empty feed and is logged" do
    it "handles text that is not JSON" do
      loader = load_text("this is not json")

      expect(loader.sailings).to be_empty
      expect(log.string).to include("ERROR").and include("not valid JSON")
    end

    it "handles a missing section" do
      document = { "sailings" => [], "rates" => [] }

      expect(load(document).sailings).to be_empty
      expect(log.string).to include("must hold 'sailings' and 'rates' arrays")
    end

    it "handles a document that is not an object" do
      expect(load([1, 2, 3]).sailings).to be_empty
      expect(log.string).to include("must hold 'sailings' and 'rates' arrays")
    end
  end

  describe "a dirty sailing is dropped and logged" do
    it "drops a record that is not an object" do
      document = with_sailing({})
      document["sailings"] = ["S001"]

      expect(load(document).sailings).to be_empty
      expect(log.string).to include("Skipped sailing \"S001\": not an object")
    end

    it "drops a sailing with a missing field" do
      loader = load(with_sailing("arrival_date" => nil))

      expect(loader.sailings).to be_empty
      expect(log.string).to include("WARN").and include("arrival_date must be a non-empty string")
    end

    it "drops a sailing with a date that is not YYYY-MM-DD" do
      expect(load(with_sailing("departure_date" => "01/02/2022")).sailings).to be_empty
      expect(log.string).to include("dates must be YYYY-MM-DD")
    end

    it "drops a sailing that arrives before it departs" do
      expect(load(with_sailing("arrival_date" => "2022-01-31")).sailings).to be_empty
      expect(log.string).to include("S001").and include("arrives on 2022-01-31, not after its departure on 2022-02-01")
    end

    it "drops a sailing that arrives on the day it departs" do
      expect(load(with_sailing("arrival_date" => "2022-02-01")).sailings).to be_empty
    end

    it "keeps a sailing that arrives the day after it departs" do
      expect(load(with_sailing("arrival_date" => "2022-02-02")).sailings.length).to eq(1)
    end

    it "drops a sailing without a rate" do
      expect(load(with_sailing("sailing_code" => "NORATE")).sailings).to be_empty
      expect(log.string).to include("NORATE").and include("no rate")
    end

    it "drops a sailing whose departure date has no exchange rates" do
      document = with_sailing({})
      document["exchange_rates"] = { "2022-02-02" => { "usd" => 1.5 } }

      expect(load(document).sailings).to be_empty
      expect(log.string).to include("no USD exchange rate for 2022-02-01")
    end

    it "drops a sailing whose currency has no exchange rate on its departure date" do
      document = with_sailing({})
      document["exchange_rates"] = { "2022-02-01" => { "jpy" => 130.85 } }

      expect(load(document).sailings).to be_empty
      expect(log.string).to include("no USD exchange rate for 2022-02-01")
    end

    it "keeps a EUR sailing even when its date has no exchange rates" do
      document = with_sailing({})
      document["rates"] = [{ "sailing_code" => "S001", "rate" => "10.00", "rate_currency" => "EUR" }]
      document["exchange_rates"] = {}

      expect(load(document).sailings.length).to eq(1)
    end
  end

  describe "a dirty rate is dropped and logged" do
    def with_rate(raw_rate)
      document = JSON.parse(JSON.generate(feed))
      document["rates"] = [raw_rate]
      return document
    end

    it "drops a rate that is not an object" do
      loader = load(with_rate("10.50"))

      expect(loader.rate_book.rate?("S001")).to be(false)
      expect(log.string).to include("Skipped rate \"10.50\": not an object")
    end

    it "drops a rate without a currency" do
      loader = load(with_rate({ "sailing_code" => "S001", "rate" => "10.50" }))

      expect(loader.rate_book.rate?("S001")).to be(false)
      expect(log.string).to include("rate_currency must be a non-empty string")
    end

    it "drops a rate that is not a number" do
      load(with_rate({ "sailing_code" => "S001", "rate" => "ten", "rate_currency" => "USD" }))

      expect(log.string).to include("rate must be a non-negative number")
    end

    it "drops a rate that is not a finite number" do
      load(with_rate({ "sailing_code" => "S001", "rate" => "Infinity", "rate_currency" => "USD" }))

      expect(log.string).to include("rate must be a non-negative number")
    end

    it "drops a negative rate" do
      load(with_rate({ "sailing_code" => "S001", "rate" => "-1.00", "rate_currency" => "USD" }))

      expect(log.string).to include("rate must be a non-negative number")
    end

    it "keeps the clean duplicate when the other one is dirty" do
      document = JSON.parse(JSON.generate(feed))
      document["rates"][1]["rate"] = "abc"

      expect(load(document).rate_book.rate_for("S001").original_text).to eq("10.50")
    end

    it "drops duplicates in different currencies, and with them the sailing" do
      document = JSON.parse(JSON.generate(feed))
      document["rates"][1]["rate_currency"] = "EUR"
      loader = load(document)

      expect(loader.rate_book.rate?("S001")).to be(false)
      expect(loader.sailings).to be_empty
      expect(log.string).to include("conflicting currencies USD, EUR")
    end
  end

  describe "a dirty exchange rate is dropped and logged" do
    def with_exchange_rates(raw_exchange_rates)
      document = JSON.parse(JSON.generate(feed))
      document["exchange_rates"] = raw_exchange_rates
      return document
    end

    it "drops a date key that is not YYYY-MM-DD" do
      loader = load(with_exchange_rates({ "1 Feb 2022" => { "usd" => 1.5 } }))

      expect(loader.sailings).to be_empty
      expect(log.string).to include("Skipped exchange rates for \"1 Feb 2022\"")
    end

    it "drops a date whose rates are not an object" do
      load(with_exchange_rates({ "2022-02-01" => 1.5 }))

      expect(log.string).to include("Skipped exchange rates for \"2022-02-01\"")
    end

    it "drops a rate of zero, which would divide by zero" do
      loader = load(with_exchange_rates({ "2022-02-01" => { "usd" => 0 } }))

      expect(loader.sailings).to be_empty
      expect(log.string).to include("Skipped usd exchange rate for 2022-02-01: 0 is not a positive number")
    end

    it "drops a rate that is not a number" do
      load(with_exchange_rates({ "2022-02-01" => { "usd" => "1.5" } }))

      expect(log.string).to include("\"1.5\" is not a positive number")
    end
  end

  describe ".from_file" do
    it "reads the feed from a file" do
      from_file = RouteFinder::Feed::Loader.from_file(sample_feed_path, highest, silent_logger)

      expect(from_file.sailings.length).to eq(9)
    end

    it "uses an empty feed and logs the error when the file cannot be read" do
      missing_path = File.join(Dir.tmpdir, "no-such-feed-#{Process.pid}.json")
      from_file = RouteFinder::Feed::Loader.from_file(missing_path, highest, logger_and_output[0])

      expect(from_file.sailings).to be_empty
      expect(log.string).to include("Cannot read feed #{missing_path}")
    end
  end
end
