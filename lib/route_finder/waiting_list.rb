# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "errors"

module RouteFinder
  # A part of the search cannot be used in a file name.
  class InvalidSearchRequestError < Error; end

  # saved searches: searches that had no route, re-run whenever the feed changes.
  #
  # Two directories:
  #   waiting_dir       - <ORIGIN>_<DEST>_<criteria>.json holding the request;
  #   notifications_dir - the same file name holding the route in the README format.
  #
  # Storage, delivery and the pass deliberately share one class. The cut lines if a
  # database or webhook is needed: `fulfil` -> a Notifier, `process` -> a Fulfiller.
  class WaitingList
    # \A and \z anchor the whole string (^ and $ would stop at a newline), so a part
    # such as "../../etc" can never escape the directory.
    SAFE_NAME_PART = /\A[A-Za-z0-9-]+\z/

    def initialize(waiting_dir, notifications_dir)
      @waiting_dir = waiting_dir
      @notifications_dir = notifications_dir
    end

    # Saves a search and returns the file name. The name has no date or id, so saving
    # the same search again overwrites the same file.
    def save(origin_port, destination_port, criteria_name)
      check_name_part(origin_port)
      check_name_part(destination_port)
      check_name_part(criteria_name)

      request = {
        "origin_port" => origin_port,
        "destination_port" => destination_port,
        "criteria" => criteria_name
      }

      file_name = "#{origin_port}_#{destination_port}_#{criteria_name}.json"
      write_atomically(File.join(@waiting_dir, file_name), JSON.pretty_generate(request))
      return file_name
    end

    # One pass: re-runs every waiting search on the current feed and moves those that
    # now have a route to notifications. Returns the names it fulfilled.
    # A corrupt request file is logged and skipped, so it cannot block the others.
    def process(factory, presenter, logger)
      fulfilled_names = []

      # *.json only: temporary *.json.tmp files are never picked up.
      paths = Dir.glob(File.join(@waiting_dir, "*.json")).sort

      paths.each do |path|
        file_name = File.basename(path)

        begin
          fulfilled = process_file(path, factory, presenter)
          if fulfilled
            logger.info("Fulfilled #{file_name}: moved to notifications")
            fulfilled_names.push(file_name)
          end
        rescue JSON::ParserError, KeyError, RouteFinder::Error => error
          logger.warn("Skipped waiting-list file #{file_name}: #{error.message}")
        end
      end

      return fulfilled_names
    end

    private

    # Returns true when the search now has a route and was moved to notifications.
    def process_file(path, factory, presenter)
      request = JSON.parse(File.read(path))

      criteria = factory.build(request.fetch("criteria"))
      sailings = criteria.find_route(request.fetch("origin_port"), request.fetch("destination_port"))

      if sailings.empty?
        return false
      end

      fulfil(path, presenter.render(sailings))
      return true
    end

    # Writes the notification first and deletes the request only afterwards: a crash in
    # between re-processes the request on the next pass but never loses it.
    def fulfil(path, rendered_json)
      notification_path = File.join(@notifications_dir, File.basename(path))
      write_atomically(notification_path, rendered_json)

      File.delete(path)
    end

    # A reader sees either the old content or the new one, never half a file:
    # write to a temporary file, then rename it over the target.
    def write_atomically(path, text)
      FileUtils.mkdir_p(File.dirname(path))

      temp_path = path + ".tmp"
      File.open(temp_path, "w") do |file|
        file.puts(text)
      end

      File.rename(temp_path, path)
    end

    def check_name_part(value)
      if !SAFE_NAME_PART.match?(value)
        raise InvalidSearchRequestError,
              "Cannot save the search: '#{value}' may contain only letters, digits and '-'"
      end
    end
  end
end
