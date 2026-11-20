# frozen_string_literal: true

require "bigdecimal"
require "date"
require "json"
require_relative "../money"
require_relative "exchange_rates"
require_relative "rate_book"
require_relative "sailing"

module RouteFinder
  module Feed
    # Turns the rates feed into clean domain objects.
    #
    # The feed is not guaranteed to be clean, so nothing here raises:
    # - a broken document (unreadable, not JSON, missing sections) becomes an empty feed;
    # - a dirty record is dropped;
    # - a sailing that cannot be priced in EUR is dropped.
    # Every drop is logged for the administrator; searches only ever see clean sailings.
    class Loader
      EMPTY_DOCUMENT = { "sailings" => [], "rates" => [], "exchange_rates" => {} }.freeze

      SAILING_FIELDS = ["origin_port", "destination_port", "departure_date", "arrival_date", "sailing_code"].freeze
      RATE_FIELDS = ["sailing_code", "rate", "rate_currency"].freeze

      def self.from_file(path, resolver, logger)
        begin
          json_text = File.read(path)
        rescue SystemCallError => error
          logger.error("Cannot read feed #{path}, using an empty feed: #{error.message}")
          json_text = JSON.generate(EMPTY_DOCUMENT)
        end
        return new(json_text, resolver, logger)
      end

      attr_reader :sailings, :rate_book, :exchange_rates

      def initialize(json_text, resolver, logger)
        @logger = logger
        document = parse_document(json_text)

        # Rates and exchange rates first: a sailing is kept only if it can be priced.
        @exchange_rates = build_exchange_rates(document["exchange_rates"])
        @rate_book = build_rate_book(document["rates"], resolver)
        @sailings = build_sailings(document["sailings"])
      end

      private

      def parse_document(json_text)
        begin
          document = JSON.parse(json_text, decimal_class: BigDecimal)
        rescue JSON::ParserError => error
          @logger.error("Feed is not valid JSON, using an empty feed: #{error.message}")
          return EMPTY_DOCUMENT
        end

        if !well_formed?(document)
          @logger.error("Feed must hold 'sailings' and 'rates' arrays and an 'exchange_rates' object, " \
                        "using an empty feed")
          return EMPTY_DOCUMENT
        end
        return document
      end

      def well_formed?(document)
        if !document.is_a?(Hash)
          return false
        end
        return document["sailings"].is_a?(Array) &&
               document["rates"].is_a?(Array) &&
               document["exchange_rates"].is_a?(Hash)
      end

      def build_sailings(raw_sailings)
        sailings = []
        raw_sailings.each do |raw_sailing|
          problem = sailing_problem(raw_sailing)
          if problem.nil?
            sailings.push(to_sailing(raw_sailing))
          else
            @logger.warn("Skipped sailing #{JSON.generate(raw_sailing)}: #{problem}")
          end
        end
        return sailings
      end

      # Why a sailing record cannot be used for a search, or nil when it is clean.
      def sailing_problem(raw_sailing)
        problem = missing_field(raw_sailing, SAILING_FIELDS)
        if !problem.nil?
          return problem
        end

        departure_date = parse_date(raw_sailing["departure_date"])
        arrival_date = parse_date(raw_sailing["arrival_date"])
        if departure_date.nil? || arrival_date.nil?
          return "dates must be YYYY-MM-DD"
        end
        if arrival_date <= departure_date
          return "arrives on #{arrival_date}, not after its departure on #{departure_date}"
        end

        sailing_code = raw_sailing["sailing_code"]
        if !@rate_book.rate?(sailing_code)
          return "no rate"
        end
        currency = @rate_book.rate_for(sailing_code).currency
        if !@exchange_rates.convertible?(currency, departure_date)
          return "no #{currency} exchange rate for #{departure_date}"
        end
        return nil
      end

      def to_sailing(raw_sailing)
        return Sailing.new(
          raw_sailing["origin_port"],
          raw_sailing["destination_port"],
          Date.iso8601(raw_sailing["departure_date"]),
          Date.iso8601(raw_sailing["arrival_date"]),
          raw_sailing["sailing_code"]
        )
      end

      # Groups valid rates by sailing code; the resolver picks one rate per code.
      def build_rate_book(raw_rates, resolver)
        candidates_by_code = {}
        raw_rates.each do |raw_rate|
          problem = rate_problem(raw_rate)
          if !problem.nil?
            @logger.warn("Skipped rate #{JSON.generate(raw_rate)}: #{problem}")
            next
          end

          sailing_code = raw_rate["sailing_code"]
          if !candidates_by_code.key?(sailing_code)
            candidates_by_code[sailing_code] = []
          end
          candidates_by_code[sailing_code].push(Money.from_text(raw_rate["rate"], raw_rate["rate_currency"]))
        end

        return RateBook.new(single_currency_only(candidates_by_code), resolver)
      end

      def rate_problem(raw_rate)
        problem = missing_field(raw_rate, RATE_FIELDS)
        if !problem.nil?
          return problem
        end

        amount = parse_amount(raw_rate["rate"])
        if amount.nil? || amount.negative?
          return "rate must be a non-negative number"
        end
        return nil
      end

      # Duplicate rates in different currencies cannot be compared, so the code is dropped.
      def single_currency_only(candidates_by_code)
        clean = {}
        candidates_by_code.each do |sailing_code, candidates|
          currencies = candidates.map { |money| money.currency }.uniq
          if currencies.length == 1
            clean[sailing_code] = candidates
          else
            @logger.warn("Skipped rates for sailing #{sailing_code}: conflicting currencies #{currencies.join(", ")}")
          end
        end
        return clean
      end

      # Exchange rates are EUR-based and keyed by date; currency codes are upper-cased.
      def build_exchange_rates(raw_exchange_rates)
        rates_by_date = {}
        raw_exchange_rates.each do |date_text, raw_currency_rates|
          date = parse_date(date_text)
          if date.nil? || !raw_currency_rates.is_a?(Hash)
            @logger.warn("Skipped exchange rates for #{date_text.inspect}: " \
                         "expected a YYYY-MM-DD key holding an object of rates")
            next
          end
          rates_by_date[date] = build_currency_rates(date_text, raw_currency_rates)
        end
        return ExchangeRates.new(rates_by_date)
      end

      def build_currency_rates(date_text, raw_currency_rates)
        currency_rates = {}
        raw_currency_rates.each do |currency_code, raw_value|
          if raw_value.is_a?(Numeric) && raw_value.positive?
            currency_rates[currency_code.upcase] = BigDecimal(raw_value.to_s)
          else
            @logger.warn("Skipped #{currency_code} exchange rate for #{date_text}: " \
                         "#{raw_value.inspect} is not a positive number")
          end
        end
        return currency_rates
      end

      def missing_field(raw_record, fields)
        if !raw_record.is_a?(Hash)
          return "not an object"
        end
        fields.each do |field|
          value = raw_record[field]
          if !value.is_a?(String) || value.empty?
            return "#{field} must be a non-empty string"
          end
        end
        return nil
      end

      def parse_date(text)
        begin
          return Date.iso8601(text)
        rescue Date::Error
          return nil
        end
      end

      def parse_amount(text)
        begin
          amount = BigDecimal(text)
        rescue ArgumentError
          return nil
        end
        if !amount.finite?
          return nil
        end
        return amount
      end
    end
  end
end
