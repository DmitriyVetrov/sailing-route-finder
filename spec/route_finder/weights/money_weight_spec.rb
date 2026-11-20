# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Weights::MoneyWeight do
  def weight(amount, legs)
    return RouteFinder::Weights::MoneyWeight.new(BigDecimal(amount), legs)
  end

  it_behaves_like "a weight" do
    let(:generator) do
      ->(random) { RouteFinder::Weights::MoneyWeight.new(BigDecimal(random.rand(0..5)), random.rand(0..3)) }
    end
    let(:zero) { RouteFinder::Weights::MoneyWeight.zero }
  end

  describe "#+" do
    it "adds amounts and legs and returns a new weight" do
      left = weight("10.50", 1)
      right = weight("2.25", 2)

      sum = left + right

      expect(sum.amount).to eq(BigDecimal("12.75"))
      expect(sum.legs).to eq(3)
      expect(left.amount).to eq(BigDecimal("10.50"))
    end
  end

  describe "#<=>" do
    it "orders by amount first" do
      expect(weight("9", 5)).to be < weight("10", 1)
    end

    it "breaks a tie by the number of legs" do
      expect(weight("10", 1)).to be < weight("10", 2)
    end

    it "treats equal amount and legs as equal" do
      expect(weight("10", 2)).to eq(weight("10.0", 2))
    end

    it "is not comparable with another type" do
      expect(weight("10", 1) <=> 10).to be_nil
    end
  end

  describe "construction" do
    it "rejects a negative amount" do
      expect { weight("-1", 0) }.to raise_error(RouteFinder::NegativeWeightError)
    end

    it "rejects a negative number of legs" do
      expect { weight("1", -1) }.to raise_error(RouteFinder::NegativeWeightError)
    end

    it "is frozen" do
      expect(weight("1", 1)).to be_frozen
    end
  end

  describe ".zero" do
    it "has no amount and no legs" do
      zero = RouteFinder::Weights::MoneyWeight.zero

      expect(zero.amount).to eq(BigDecimal("0"))
      expect(zero.legs).to eq(0)
    end
  end
end
