# frozen_string_literal: true

require "spec_helper"

# The CLI against the real sample feed, with StringIO in place of the process streams:
# input -> factory -> criteria -> presenter -> output.
RSpec.describe RouteFinder::CLI do
  let(:output) { StringIO.new }
  let(:error_output) { StringIO.new }
  let(:logger_and_output) { capturing_logger }
  let(:log) { logger_and_output[1] }

  # Overridden by a nested group to show that the duplicate-rate policy is replaceable.
  let(:resolver) { highest_rate }

  let(:loader) { load_feed(sample_feed_path, resolver) }

  # WaitingList itself is covered by waiting_list_spec.rb; here a double is enough.
  let(:waiting_list) { double("waiting_list", save: "SAVED_FILE.json") }

  def run_with_input(text)
    factory = RouteFinder::CriteriaFactory.new(loader.sailings, cost_calculator_for(loader))
    presenter = RouteFinder::Presenter::LegsPresenter.new(loader.rate_book)

    cli = RouteFinder::CLI.new(
      input: StringIO.new(text),
      output: output,
      error_output: error_output,
      factory: factory,
      presenter: presenter,
      waiting_list: waiting_list,
      logger: logger_and_output[0]
    )
    return cli.run
  end

  describe "with the cheapest-direct criteria" do
    it "prints the cheapest direct sailing in the format of the README" do
      status = run_with_input("CNSHA\nNLRTM\ncheapest-direct\n")

      expect(status).to eq(RouteFinder::CLI::EXIT_SUCCESS)
      expect(JSON.parse(output.string)).to eq(
        [
          {
            "origin_port" => "CNSHA",
            "destination_port" => "NLRTM",
            "departure_date" => "2022-02-01",
            "arrival_date" => "2022-03-01",
            "sailing_code" => "ABCD",
            "rate" => "589.30",
            "rate_currency" => "USD"
          }
        ]
      )
    end

    it "echoes the original USD price, not its EUR equivalent (523.36)" do
      run_with_input("CNSHA\nNLRTM\ncheapest-direct\n")

      expect(output.string).to include('"rate": "589.30"')
      expect(output.string).to include('"rate_currency": "USD"')
      expect(output.string).not_to include("523.36")
    end

    it "writes nothing to stderr" do
      run_with_input("CNSHA\nNLRTM\ncheapest-direct\n")

      expect(error_output.string).to be_empty
    end

    it "ignores surrounding whitespace and Windows line endings" do
      status = run_with_input("  CNSHA \r\nNLRTM\r\ncheapest-direct\r\n")

      expect(status).to eq(RouteFinder::CLI::EXIT_SUCCESS)
      expect(JSON.parse(output.string)[0]["sailing_code"]).to eq("ABCD")
    end

    it "accepts lower-case port codes" do
      run_with_input("cnsha\nNlRtM\ncheapest-direct\n")

      expect(JSON.parse(output.string)[0]["sailing_code"]).to eq("ABCD")
    end

    it "answers CNSHA -> ESBCN with its only direct sailing" do
      run_with_input("CNSHA\nESBCN\ncheapest-direct\n")

      legs = JSON.parse(output.string)

      expect(legs.map { |leg| leg["sailing_code"] }).to eq(["ERXQ"])
      expect(legs[0]["rate"]).to eq("261.96")
      expect(legs[0]["rate_currency"]).to eq("EUR")
    end

    it "prints [] and succeeds when there is no direct sailing" do
      # BRSSZ is reachable only through ESBCN.
      status = run_with_input("CNSHA\nBRSSZ\ncheapest-direct\n")

      expect(status).to eq(RouteFinder::CLI::EXIT_SUCCESS)
      expect(output.string).to eq("[]\n")
    end

    it "prints [] for a direction that exists only the other way round" do
      run_with_input("NLRTM\nCNSHA\ncheapest-direct\n")

      expect(output.string).to eq("[]\n")
    end

    it "prints [] for a well-formed port that is not in the feed" do
      run_with_input("XXXXX\nNLRTM\ncheapest-direct\n")

      expect(output.string).to eq("[]\n")
    end
  end

  # saved searches: an empty result is saved to the waiting list.
  describe "waiting list" do
    it "saves the search, with upper-cased ports, when there is no route" do
      run_with_input("cnsha\nbrssz\ncheapest-direct\n")

      expect(waiting_list).to have_received(:save).with("CNSHA", "BRSSZ", "cheapest-direct")
    end

    it "logs where the search was saved, and shows the user only []" do
      run_with_input("CNSHA\nBRSSZ\ncheapest-direct\n")

      expect(output.string).to eq("[]\n")
      expect(error_output.string).to be_empty
      expect(log.string).to include("saved to the waiting list as SAVED_FILE.json")
    end

    it "does not touch the waiting list when a route is found" do
      run_with_input("CNSHA\nNLRTM\ncheapest-direct\n")

      expect(waiting_list).not_to have_received(:save)
    end

    it "prints nothing to stdout and fails when the search cannot be saved" do
      allow(waiting_list).to receive(:save).and_raise(
        RouteFinder::InvalidSearchRequestError, "Cannot save the search: disk full"
      )

      status = run_with_input("CNSHA\nBRSSZ\ncheapest-direct\n")

      expect(status).to eq(RouteFinder::CLI::EXIT_FAILURE)
      expect(output.string).to be_empty
      expect(error_output.string).to eq("Cannot save the search: disk full\n")
    end
  end

  describe "when the policy for duplicate rates is 'lowest' instead of 'highest'" do
    let(:resolver) { LowestRateResolver.new }

    it "answers MNOP with its original 456.78 USD (410.11 EUR stays internal)" do
      run_with_input("CNSHA\nNLRTM\ncheapest-direct\n")

      legs = JSON.parse(output.string)

      expect(legs[0]["sailing_code"]).to eq("MNOP")
      expect(legs[0]["rate"]).to eq("456.78")
      expect(legs[0]["rate_currency"]).to eq("USD")
      expect(output.string).not_to include("410.11")
    end
  end

  # Every input error: one line on stderr, nothing on stdout, exit 1, nothing saved.
  describe "invalid input" do
    def expect_input_error(text, message)
      status = run_with_input(text)

      expect(status).to eq(RouteFinder::CLI::EXIT_FAILURE)
      expect(output.string).to be_empty
      expect(error_output.string).to eq("#{message}\n")
      expect(waiting_list).not_to have_received(:save)
    end

    it "rejects empty input" do
      expect_input_error(
        "",
        "Expected three lines: origin port, destination port and criteria; the origin port is missing"
      )
    end

    it "rejects input with only two lines" do
      expect_input_error(
        "CNSHA\nNLRTM\n",
        "Expected three lines: origin port, destination port and criteria; the criteria is missing"
      )
    end

    it "rejects a blank line" do
      expect_input_error(
        "CNSHA\n   \ncheapest\n",
        "Expected three lines: origin port, destination port and criteria; the destination port is missing"
      )
    end

    it "rejects a port code that is not 5 letters or digits" do
      expect_input_error(
        "CNSH\nNLRTM\ncheapest\n",
        "Invalid origin port \"CNSH\": expected a 5-character port code such as CNSHA"
      )
    end

    it "rejects a port code that would escape the waiting-list directory" do
      expect_input_error(
        "CNSHA\n../..\ncheapest\n",
        "Invalid destination port \"../..\": expected a 5-character port code such as CNSHA"
      )
    end

    it "rejects the same port as origin and destination" do
      expect_input_error(
        "CNSHA\ncnsha\ncheapest\n",
        "The origin and destination port are the same (CNSHA)"
      )
    end

    it "rejects an unknown criteria and lists the registered ones" do
      expected_names = RouteFinder::CriteriaFactory::CRITERIA.keys.join(", ")

      expect_input_error(
        "CNSHA\nNLRTM\nslowest\n",
        "Unknown criteria \"slowest\". Expected one of: #{expected_names}."
      )
    end

    it "treats the criteria as case-sensitive" do
      status = run_with_input("CNSHA\nNLRTM\nCHEAPEST\n")

      expect(status).to eq(RouteFinder::CLI::EXIT_FAILURE)
    end
  end

  describe "when the search fails with any other error of ours (RouteFinder::Error)" do
    def run_with_failing_search
      criteria = double("criteria")
      allow(criteria).to receive(:find_route).and_raise(
        RouteFinder::RateNotFoundError, "No rate in the feed for sailing ZZZZ"
      )
      factory = double("factory", build: criteria)

      cli = RouteFinder::CLI.new(
        input: StringIO.new("CNSHA\nNLRTM\ncheapest\n"),
        output: output,
        error_output: error_output,
        factory: factory,
        presenter: double("presenter"),
        waiting_list: double("waiting_list"),
        logger: silent_logger
      )
      return cli.run
    end

    it "prints the message on stderr, nothing on stdout, and fails" do
      status = run_with_failing_search

      expect(status).to eq(RouteFinder::CLI::EXIT_FAILURE)
      expect(error_output.string).to eq("No rate in the feed for sailing ZZZZ\n")
      expect(output.string).to be_empty
    end
  end
end
