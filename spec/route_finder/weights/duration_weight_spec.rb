# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Weights::DurationWeight do
  def weight(days, legs)
    return RouteFinder::Weights::DurationWeight.new(days, legs)
  end

  it_behaves_like "a weight" do
    let(:generator) do
      ->(random) { RouteFinder::Weights::DurationWeight.new(random.rand(0..5), random.rand(0..3)) }
    end
    let(:zero) { RouteFinder::Weights::DurationWeight.zero }
  end

  describe "#+" do
    it "adds days and legs and returns a new weight" do
      sum = weight(4, 1) + weight(3, 2)

      expect(sum.days).to eq(7)
      expect(sum.legs).to eq(3)
    end
  end

  describe "#<=>" do
    it "orders by days first" do
      expect(weight(2, 9)).to be < weight(3, 1)
    end

    it "breaks a tie by the number of legs" do
      expect(weight(5, 1)).to be < weight(5, 2)
    end

    it "is not comparable with another type" do
      expect(weight(5, 1) <=> 5).to be_nil
    end
  end

  describe "construction" do
    it "rejects negative days" do
      expect { weight(-1, 0) }.to raise_error(RouteFinder::NegativeWeightError)
    end

    it "rejects a negative number of legs" do
      expect { weight(1, -1) }.to raise_error(RouteFinder::NegativeWeightError)
    end

    it "is frozen" do
      expect(weight(1, 1)).to be_frozen
    end
  end

  describe ".zero" do
    it "has no days and no legs" do
      zero = RouteFinder::Weights::DurationWeight.zero

      expect(zero.days).to eq(0)
      expect(zero.legs).to eq(0)
    end
  end
end
