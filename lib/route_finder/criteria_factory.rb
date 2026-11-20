# frozen_string_literal: true

require_relative "errors"
require_relative "criteria/cheapest_direct"
require_relative "criteria/cheapest"
require_relative "criteria/fastest"

module RouteFinder
  # Builds the criteria named on the third input line.
  # A registry rather than a case statement: a new criteria is one class plus one line here.
  # The criteria classes are required at the top because this hash references them on load.
  class CriteriaFactory
    CRITERIA = {
      "cheapest-direct" => Criteria::CheapestDirect,
      "cheapest" => Criteria::Cheapest,
      "fastest" => Criteria::Fastest
    }.freeze

    def initialize(sailings, cost_calculator)
      @sailings = sailings
      @cost_calculator = cost_calculator
    end

    def build(criteria_name)
      criteria_class = find_class(criteria_name)
      return criteria_class.new(@sailings, @cost_calculator)
    end

    private

    # KeyError becomes a domain error, so the CLI reports it like any other input error.
    def find_class(criteria_name)
      begin
        return CRITERIA.fetch(criteria_name)
      rescue KeyError
        expected = CRITERIA.keys.join(", ")
        raise UnknownCriteriaError,
              "Unknown criteria \"#{criteria_name}\". Expected one of: #{expected}."
      end
    end
  end
end
