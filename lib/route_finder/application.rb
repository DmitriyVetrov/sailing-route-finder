# frozen_string_literal: true

require "fileutils"
require "logger"
require_relative "criteria_factory"
require_relative "feed/eur_cost_calculator"
require_relative "feed/loader"
require_relative "feed/rate_resolvers/highest_rate"
require_relative "presenter/legs_presenter"
require_relative "waiting_list"

module RouteFinder
  # Composition root: builds everything the entry points need from one feed file.
  # The waiting list, the notifications and the log live next to the feed, so
  # FEED_PATH is the only setting.
  class Application
    DEFAULT_FEED_PATH = File.expand_path("../../data/response.json", __dir__)
    LOG_FILE_NAME = "route_finder.log"

    attr_reader :factory, :presenter, :waiting_list, :logger

    # The feed path from FEED_PATH, or the bundled sample feed.
    def self.feed_path_from(env)
      return env.fetch("FEED_PATH", DEFAULT_FEED_PATH)
    end

    # program_name tags every log line, so the log shows which entry point wrote it.
    def initialize(feed_path, program_name)
      data_dir = File.dirname(feed_path)
      @logger = build_logger(File.join(data_dir, "logs", LOG_FILE_NAME), program_name)

      # Duplicate rates: the highest wins (confirmed by the PO).
      resolver = Feed::RateResolvers::HighestRate.new
      loader = Feed::Loader.from_file(feed_path, resolver, @logger)
      cost_calculator = Feed::EurCostCalculator.new(loader.rate_book, loader.exchange_rates)

      @factory = CriteriaFactory.new(loader.sailings, cost_calculator)
      @presenter = Presenter::LegsPresenter.new(loader.rate_book)
      @waiting_list = WaitingList.new(
        File.join(data_dir, "waiting_list"),
        File.join(data_dir, "notifications")
      )
    end

    private

    def build_logger(log_path, program_name)
      FileUtils.mkdir_p(File.dirname(log_path))
      return Logger.new(log_path, progname: program_name)
    end
  end
end
