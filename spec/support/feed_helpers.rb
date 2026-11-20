# frozen_string_literal: true

require "logger"
require "stringio"

# Shared helpers for specs that need sailings, a loaded feed or rates.
# Mixed into every example group by spec_helper.rb.
module FeedHelpers
  def sample_feed_path
    return File.expand_path("../../data/response.json", __dir__)
  end

  def three_leg_feed_path
    return File.expand_path("../fixtures/three_leg.json", __dir__)
  end

  def highest_rate
    return RouteFinder::Feed::RateResolvers::HighestRate.new
  end

  # A logger that discards everything, for specs that do not check the log.
  def silent_logger
    return Logger.new(nil)
  end

  # A logger plus the StringIO it writes to, for specs that check the log.
  def capturing_logger
    log_output = StringIO.new
    return [Logger.new(log_output), log_output]
  end

  def load_feed(path, resolver)
    return RouteFinder::Feed::Loader.from_file(path, resolver, silent_logger)
  end

  def load_sample_feed
    return load_feed(sample_feed_path, highest_rate)
  end

  def cost_calculator_for(loader)
    return RouteFinder::Feed::EurCostCalculator.new(loader.rate_book, loader.exchange_rates)
  end

  def sailing(code, origin, destination, departure_date, arrival_date)
    return RouteFinder::Feed::Sailing.new(origin, destination, departure_date, arrival_date, code)
  end

  def codes_of(route)
    return route.map { |leg| leg.sailing_code }
  end

  def money(text, currency)
    return RouteFinder::Money.from_text(text, currency)
  end

  def usd(text)
    return money(text, "USD")
  end

  # prices: { "ABCD" => ["589.30", "USD"] }
  def rate_book_from(prices)
    candidates_by_code = {}
    prices.each do |code, price|
      candidates_by_code[code] = [money(price[0], price[1])]
    end
    return RouteFinder::Feed::RateBook.new(candidates_by_code, highest_rate)
  end
end
