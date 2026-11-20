# frozen_string_literal: true

require_relative "../errors"

module RouteFinder
  module Feed
    # Rate lookup: sailing_code -> one Money.
    # Which rate wins when the feed has several is delegated to the injected resolver.
    class RateBook
      # candidates_by_code: { "MNOP" => [Money, Money], "ABCD" => [Money] }
      # resolver: any object answering resolve(candidates), see RateResolvers.
      def initialize(candidates_by_code, resolver)
        @rates_by_code = {}

        candidates_by_code.each do |code, candidates|
          @rates_by_code[code] = resolver.resolve(candidates)
        end

        @rates_by_code.freeze
      end

      def rate?(sailing_code)
        return @rates_by_code.key?(sailing_code)
      end

      # Raises rather than returning nil, so a missing rate fails where it is looked up.
      def rate_for(sailing_code)
        rate = @rates_by_code.fetch(sailing_code, nil)
        if rate.nil?
          raise RateNotFoundError, "No rate in the feed for sailing #{sailing_code}"
        end

        return rate
      end
    end
  end
end
