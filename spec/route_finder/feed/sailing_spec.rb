# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Feed::Sailing do
  let(:abcd) do
    RouteFinder::Feed::Sailing.new(
      "CNSHA", "NLRTM", Date.new(2022, 2, 1), Date.new(2022, 3, 1), "ABCD"
    )
  end

  it "exposes the fields it was built with" do
    expect(abcd.origin_port).to eq("CNSHA")
    expect(abcd.destination_port).to eq("NLRTM")
    expect(abcd.departure_date).to eq(Date.new(2022, 2, 1))
    expect(abcd.arrival_date).to eq(Date.new(2022, 3, 1))
    expect(abcd.sailing_code).to eq("ABCD")
  end

  describe "#duration_days" do
    it "is the whole number of days between departure and arrival" do
      expect(abcd.duration_days).to eq(28)
    end

    it "returns an Integer, not the Rational that date subtraction produces" do
      expect(abcd.duration_days).to be_a(Integer)
    end

    it "counts across a year boundary" do
      new_year = RouteFinder::Feed::Sailing.new(
        "A", "B", Date.new(2021, 12, 30), Date.new(2022, 1, 2), "YYYY"
      )

      expect(new_year.duration_days).to eq(3)
    end
  end

  it "is immutable" do
    expect(abcd).to be_frozen
  end

  it "does not carry a price" do
    expect(abcd).not_to respond_to(:rate)
  end
end
