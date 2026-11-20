# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"

# End to end: runs the real bin/route_finder as a separate process, the way a user does.
# The feed is copied into a temporary directory (FEED_PATH), so the waiting list and the
# log are written there and never into data/.
RSpec.describe "bin/route_finder" do
  let(:script) { File.expand_path("../../bin/route_finder", __dir__) }
  let(:root) { Dir.mktmpdir }
  let(:feed_path) { File.join(root, "response.json") }
  let(:log_path) { File.join(root, "logs", "route_finder.log") }

  before do
    FileUtils.cp(sample_feed_path, feed_path)
  end

  after do
    FileUtils.rm_rf(root)
  end

  # Returns [stdout, stderr, exit code].
  def run_program(input, arguments = [])
    command = [RbConfig.ruby, script] + arguments
    stdout, stderr, status = Open3.capture3({ "FEED_PATH" => feed_path }, *command, stdin_data: input)
    return [stdout, stderr, status.exitstatus]
  end

  def leg(origin, destination, departure, arrival, code, rate, currency)
    return {
      "origin_port" => origin, "destination_port" => destination,
      "departure_date" => departure, "arrival_date" => arrival,
      "sailing_code" => code, "rate" => rate, "rate_currency" => currency
    }
  end

  describe "the README searches on the sample feed" do
    it "cheapest-direct: ABCD, because the higher duplicate rate rules out MNOP" do
      stdout, stderr, code = run_program("CNSHA\nNLRTM\ncheapest-direct\n")

      expect(code).to eq(0)
      expect(stderr).to be_empty
      expect(JSON.parse(stdout)).to eq(
        [leg("CNSHA", "NLRTM", "2022-02-01", "2022-03-01", "ABCD", "589.30", "USD")]
      )
    end

    it "cheapest: ERXQ + ETRG, 322.89 EUR in total" do
      stdout, _stderr, _code = run_program("CNSHA\nNLRTM\ncheapest\n")

      expect(JSON.parse(stdout)).to eq(
        [
          leg("CNSHA", "ESBCN", "2022-01-29", "2022-02-12", "ERXQ", "261.96", "EUR"),
          leg("ESBCN", "NLRTM", "2022-02-16", "2022-02-20", "ETRG", "69.96", "USD")
        ]
      )
    end

    it "fastest: the direct QRST, 17 days (the two-leg route takes 22)" do
      stdout, _stderr, _code = run_program("CNSHA\nNLRTM\nfastest\n")

      expect(JSON.parse(stdout)).to eq(
        [leg("CNSHA", "NLRTM", "2022-01-29", "2022-02-15", "QRST", "761.96", "EUR")]
      )
    end
  end

  it "accepts the three lines as command-line arguments instead of stdin" do
    stdout, _stderr, _code = run_program("", ["CNSHA", "NLRTM", "cheapest-direct"])

    expect(JSON.parse(stdout)[0]["sailing_code"]).to eq("ABCD")
  end

  it "prints only [] when there is no route, saves the search and logs it" do
    stdout, stderr, code = run_program("CNSHA\nBRSSZ\ncheapest-direct\n")

    expect([stdout, stderr, code]).to eq(["[]\n", "", 0])
    expect(File.exist?(File.join(root, "waiting_list", "CNSHA_BRSSZ_cheapest-direct.json"))).to be(true)
    expect(File.read(log_path)).to include("route_finder: No route for CNSHA -> BRSSZ")
  end

  it "prints only [] for a broken feed; the reason is in the log and the search waits" do
    File.write(feed_path, "not json")

    stdout, stderr, code = run_program("CNSHA\nNLRTM\ncheapest\n")

    expect([stdout, stderr, code]).to eq(["[]\n", "", 0])
    expect(File.read(log_path)).to include("Feed is not valid JSON")
    expect(File.exist?(File.join(root, "waiting_list", "CNSHA_NLRTM_cheapest.json"))).to be(true)
  end

  it "prints only [] for a missing feed file" do
    File.delete(feed_path)

    stdout, _stderr, code = run_program("CNSHA\nNLRTM\ncheapest\n")

    expect([stdout, code]).to eq(["[]\n", 0])
    expect(File.read(log_path)).to include("Cannot read feed #{feed_path}")
  end

  it "searches around a dirty sailing and logs it" do
    document = JSON.parse(File.read(sample_feed_path))
    document["rates"].delete_if { |rate| rate["sailing_code"] == "QRST" }
    File.write(feed_path, JSON.generate(document))

    stdout, stderr, _code = run_program("CNSHA\nNLRTM\nfastest\n")

    # Without QRST the fastest route is ERXQ + ETRG (22 days).
    expect(JSON.parse(stdout).map { |found| found["sailing_code"] }).to eq(["ERXQ", "ETRG"])
    expect(stderr).to be_empty
    expect(File.read(log_path)).to include("Skipped sailing").and include("QRST").and include("no rate")
  end

  it "fails with one line on stderr and nothing on stdout for invalid input" do
    stdout, stderr, code = run_program("CNSHA\nNLRTM\n")

    expect(code).to eq(1)
    expect(stdout).to be_empty
    expect(stderr.lines.length).to eq(1)
  end
end
