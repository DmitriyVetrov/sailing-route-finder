# frozen_string_literal: true

# The opposite duplicate-rate policy, used to show that the resolver is replaceable.
class LowestRateResolver
  def resolve(candidates)
    return candidates.min
  end
end
