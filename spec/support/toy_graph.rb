# frozen_string_literal: true

# A textbook graph and plain integer weights for the Dijkstra specs, free of domain types.
class ToyEdge
  attr_reader :from, :to, :cost

  def initialize(from, to, cost)
    @from = from
    @to = to
    @cost = cost
  end
end

class ToyGraph
  def self.textbook
    return from_triples(
      [
        [:A, :B, 4], [:A, :C, 2], [:C, :B, 1], [:B, :D, 5], [:C, :D, 8],
        [:C, :E, 10], [:D, :E, 2], [:D, :F, 6], [:E, :F, 3]
      ]
    )
  end

  def self.from_triples(triples)
    edges = triples.map do |from, to, cost|
      ToyEdge.new(from, to, cost)
    end
    return new(edges)
  end

  def initialize(edges)
    @edges = edges
  end

  def edges_from(node)
    return @edges.select do |edge|
      edge.from == node
    end
  end
end

class ToyWeight
  include Comparable

  attr_reader :value

  def initialize(value)
    @value = value
  end

  def +(other)
    return ToyWeight.new(value + other.value)
  end

  def <=>(other)
    return value <=> other.value
  end
end

class ToyWeigher
  def weight_of(edge)
    return ToyWeight.new(edge.cost)
  end
end

class ToyMoneyWeigher
  def weight_of(edge)
    return RouteFinder::Weights::MoneyWeight.new(BigDecimal(edge.cost.to_s), 1)
  end
end
