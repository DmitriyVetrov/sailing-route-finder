# frozen_string_literal: true

require_relative "errors"

module RouteFinder
  # Reads one search (three lines) and prints the route as JSON.
  #
  # The user sees only the route, [] or a one-line input error. Everything meant for the
  # administrator (dirty feed data, saved searches) goes to the log. stdout carries JSON
  # only, so it can be piped further.
  class CLI
    EXIT_SUCCESS = 0
    EXIT_FAILURE = 1

    # UN/LOCODE shape: two letters for the country, three letters or digits for the place.
    PORT_CODE = /\A[A-Z]{2}[A-Z0-9]{3}\z/

    # Keyword arguments, so the three interchangeable streams cannot be swapped silently.
    # waiting_list: anything answering save(origin, destination, criteria).
    def initialize(input:, output:, error_output:, factory:, presenter:, waiting_list:, logger:)
      @input = input
      @output = output
      @error_output = error_output
      @factory = factory
      @presenter = presenter
      @waiting_list = waiting_list
      @logger = logger
    end

    # Runs one search and returns the exit code; only bin/route_finder exits the process.
    def run
      begin
        origin_port = read_port("origin port")
        destination_port = read_port("destination port")
        criteria_name = read_line("criteria")
        check_different_ports(origin_port, destination_port)

        criteria = @factory.build(criteria_name)
        sailings = criteria.find_route(origin_port, destination_port)

        # saved searches: no route yet, so the search waits. Saved before printing, so a failed
        # save leaves stdout empty like any other error.
        if sailings.empty?
          file_name = @waiting_list.save(origin_port, destination_port, criteria_name)
          @logger.info("No route for #{origin_port} -> #{destination_port} (#{criteria_name}): " \
                       "saved to the waiting list as #{file_name}")
        end

        @output.puts(@presenter.render(sailings))
        return EXIT_SUCCESS
      rescue RouteFinder::Error => error
        @error_output.puts(error.message)
        return EXIT_FAILURE
      end
    end

    private

    # Strips spaces and Windows line endings; a missing or blank line is an input error.
    def read_line(name)
      line = @input.gets
      if line.nil? || line.strip.empty?
        raise InvalidInputError,
              "Expected three lines: origin port, destination port and criteria; the #{name} is missing"
      end
      return line.strip
    end

    # Port codes are upper-cased once, here; the rest of the program sees only upper case.
    def read_port(name)
      port = read_line(name).upcase
      if !PORT_CODE.match?(port)
        raise InvalidInputError, "Invalid #{name} \"#{port}\": expected a 5-character port code such as CNSHA"
      end
      return port
    end

    def check_different_ports(origin_port, destination_port)
      if origin_port == destination_port
        raise InvalidInputError, "The origin and destination port are the same (#{origin_port})"
      end
    end
  end
end
