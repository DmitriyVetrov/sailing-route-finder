# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::CriteriaFactory do
  let(:cost_calculator) do
    RouteFinder::Feed::EurCostCalculator.new(
      rate_book_from({}),
      RouteFinder::Feed::ExchangeRates.new({})
    )
  end

  let(:factory) { RouteFinder::CriteriaFactory.new([], cost_calculator) }

  describe "the registry" do
    it "is frozen, so nobody can add a criterion at runtime" do
      expect(RouteFinder::CriteriaFactory::CRITERIA).to be_frozen
    end

    it "maps cheapest-direct to the CheapestDirect class" do
      registry = RouteFinder::CriteriaFactory::CRITERIA

      expect(registry["cheapest-direct"]).to equal(RouteFinder::Criteria::CheapestDirect)
    end

    it "maps cheapest to the Cheapest class" do
      registry = RouteFinder::CriteriaFactory::CRITERIA

      expect(registry["cheapest"]).to equal(RouteFinder::Criteria::Cheapest)
    end

    it "maps fastest to the Fastest class" do
      registry = RouteFinder::CriteriaFactory::CRITERIA

      expect(registry["fastest"]).to equal(RouteFinder::Criteria::Fastest)
    end

    it "has a class that answers find_route behind every name" do
      registry = RouteFinder::CriteriaFactory::CRITERIA

      registry.each do |name, criteria_class|
        has_method = criteria_class.method_defined?(:find_route)
        expect(has_method).to be(true), "criteria #{name} has no find_route"
      end
    end
  end

  describe "#build" do
    it "builds the criteria registered under the given name" do
      criteria = factory.build("cheapest-direct")

      expect(criteria).to be_a(RouteFinder::Criteria::CheapestDirect)
    end

    it "builds a working criteria: every criteria answers find_route" do
      criteria = factory.build("cheapest-direct")

      expect(criteria.find_route("CNSHA", "NLRTM")).to eq([])
    end

    it "raises UnknownCriteriaError for a name that is not registered" do
      expect { factory.build("slowest") }.to raise_error(RouteFinder::UnknownCriteriaError)
    end

    it "names the unknown criteria and lists the registered ones in the message" do
      expected_names = RouteFinder::CriteriaFactory::CRITERIA.keys.join(", ")

      expect { factory.build("slowest") }.to raise_error(
        RouteFinder::UnknownCriteriaError,
        "Unknown criteria \"slowest\". Expected one of: #{expected_names}."
      )
    end

    it "does not guess: names are case-sensitive" do
      expect { factory.build("Cheapest-Direct") }.to raise_error(
        RouteFinder::UnknownCriteriaError
      )
    end

    it "keeps the original KeyError as the cause of the error" do
      expect { factory.build("slowest") }.to raise_error(RouteFinder::UnknownCriteriaError) do |error|
        expect(error.cause).to be_a(KeyError)
      end
    end
  end
end
