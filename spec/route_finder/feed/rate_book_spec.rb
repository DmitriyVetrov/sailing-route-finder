# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Feed::RateBook do
  let(:highest) { highest_rate }

  let(:candidates_by_code) do
    {
      "ABCD" => [usd("589.30")],
      "MNOP" => [usd("456.78"), usd("812.00")]
    }
  end

  describe "#rate_for" do
    it "returns the single rate of a sailing without duplicates" do
      book = RouteFinder::Feed::RateBook.new(candidates_by_code, highest)

      expect(book.rate_for("ABCD").original_text).to eq("589.30")
    end

    it "asks the injected resolver to pick one of several rates" do
      book = RouteFinder::Feed::RateBook.new(candidates_by_code, highest)

      expect(book.rate_for("MNOP").original_text).to eq("812.00")
    end

    it "uses whichever policy it was given (the duplicate rule is replaceable)" do
      book = RouteFinder::Feed::RateBook.new(candidates_by_code, LowestRateResolver.new)

      expect(book.rate_for("MNOP").original_text).to eq("456.78")
    end

    it "raises a clear error for a sailing without a rate" do
      book = RouteFinder::Feed::RateBook.new(candidates_by_code, highest)

      expect { book.rate_for("ZZZZ") }.to raise_error(
        RouteFinder::RateNotFoundError, /ZZZZ/
      )
    end

    it "tells whether a sailing has a rate" do
      book = RouteFinder::Feed::RateBook.new(candidates_by_code, highest)

      expect(book.rate?("MNOP")).to be(true)
      expect(book.rate?("ZZZZ")).to be(false)
    end
  end
end
