# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Feed::RateResolvers::HighestRate do
  let(:resolver) { RouteFinder::Feed::RateResolvers::HighestRate.new }

  it "returns the only candidate when there is just one" do
    only = usd("589.30")

    expect(resolver.resolve([only])).to equal(only)
  end

  it "returns the highest of several candidates" do
    result = resolver.resolve([usd("456.78"), usd("812.00")])

    expect(result.original_text).to eq("812.00")
  end

  it "does not depend on the order of the candidates" do
    result = resolver.resolve([usd("812.00"), usd("456.78")])

    expect(result.original_text).to eq("812.00")
  end

  it "keeps the original text of the winner" do
    result = resolver.resolve([usd("100.10"), usd("99.9")])

    expect(result.original_text).to eq("100.10")
  end

  it "refuses to pick a maximum across different currencies" do
    eur = RouteFinder::Money.from_text("500.00", "EUR")

    expect { resolver.resolve([usd("456.78"), eur]) }.to raise_error(
      RouteFinder::CurrencyMismatchError
    )
  end
end
