# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::ShortestPath::PriorityQueue do
  let(:queue) { RouteFinder::ShortestPath::PriorityQueue.new }

  def push(item, priority)
    queue.push(item, ToyWeight.new(priority))
  end

  def pop_items
    items = []
    while !queue.empty?
      items << queue.pop.item
    end
    return items
  end

  it "starts empty" do
    expect(queue).to be_empty
    expect(queue.size).to eq(0)
  end

  it "returns nil when popping an empty queue" do
    expect(queue.pop).to be_nil
  end

  it "pops the smallest priority first" do
    push(:c, 3)
    push(:a, 1)
    push(:b, 2)

    expect(pop_items).to eq([:a, :b, :c])
  end

  it "pops entries with equal priority in insertion order (FIFO)" do
    push(:first, 1)
    push(:second, 1)
    push(:third, 1)

    expect(pop_items).to eq([:first, :second, :third])
  end

  it "keeps several entries for the same item (lazy deletion relies on it)" do
    push(:d, 10)
    push(:d, 8)

    expect(queue.size).to eq(2)
    expect(queue.pop.priority.value).to eq(8)
  end

  it "exposes both the item and its priority" do
    push(:x, 5)

    entry = queue.pop

    expect(entry.item).to eq(:x)
    expect(entry.priority.value).to eq(5)
  end
end
