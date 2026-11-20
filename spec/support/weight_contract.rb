# frozen_string_literal: true

require_relative "toy_graph"

# The contract every Weight type must satisfy, above all monotonicity, which Dijkstra's
# correctness relies on. Checked on random samples with a fixed seed.
module WeightContract
  SAMPLES = 300

  def self.monotonicity_violations(generator)
    random = Random.new(42)
    violations = []

    SAMPLES.times do
      a = generator.call(random)
      b = generator.call(random)
      c = generator.call(random)

      if (a <=> b) > 0
        a, b = b, a
      end

      if ((a + c) <=> (b + c)) > 0
        violations << "#{a.inspect} <= #{b.inspect}, but a + c > b + c for c = #{c.inspect}"
      end
    end

    return violations
  end

  def self.non_negativity_violations(generator, zero)
    random = Random.new(7)
    violations = []

    SAMPLES.times do
      a = generator.call(random)
      b = generator.call(random)

      if (zero <=> a) > 0
        violations << "zero is greater than #{a.inspect}"
      end

      if ((a + b) <=> a) < 0
        violations << "#{a.inspect} + #{b.inspect} is smaller than #{a.inspect}"
      end
    end

    return violations
  end
end

class BrokenAverageWeight
  attr_reader :total, :count

  def initialize(total, count)
    @total = total
    @count = count
  end

  def +(other)
    return BrokenAverageWeight.new(total + other.total, count + other.count)
  end

  def <=>(other)
    return Rational(total, count) <=> Rational(other.total, other.count)
  end
end

RSpec.shared_examples "a weight" do
  it "compares any two weights to -1, 0 or 1, never nil" do
    random = Random.new(1)

    50.times do
      result = generator.call(random) <=> generator.call(random)

      expect([-1, 0, 1]).to include(result)
    end
  end

  it "is monotonic: a <= b implies a + c <= b + c" do
    expect(WeightContract.monotonicity_violations(generator)).to eq([])
  end

  it "never lets zero exceed a weight, and addition never makes a weight smaller" do
    expect(WeightContract.non_negativity_violations(generator, zero)).to eq([])
  end

  it "treats zero as neutral for addition" do
    random = Random.new(3)

    20.times do
      weight = generator.call(random)

      expect((weight + zero) <=> weight).to eq(0)
    end
  end
end
