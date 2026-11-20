# frozen_string_literal: true

require "spec_helper"

RSpec.describe WeightContract do
  describe "a minimal weight: + and <=> plus Comparable" do
    it_behaves_like "a weight" do
      let(:generator) { ->(random) { ToyWeight.new(random.rand(0..5)) } }
      let(:zero) { ToyWeight.new(0) }
    end
  end

  describe "a deliberately broken weight (average price per leg)" do
    let(:generator) { ->(random) { BrokenAverageWeight.new(random.rand(0..20), random.rand(1..3)) } }

    it "is caught as non-monotonic" do
      violations = WeightContract.monotonicity_violations(generator)

      expect(violations).not_to be_empty
    end
  end
end
