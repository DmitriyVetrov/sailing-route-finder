# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"

# End to end: runs the real bin/process_waiting_list (what bin/watch_feed runs on every
# feed change) against a copy of the sample feed in a temporary directory.
RSpec.describe "bin/process_waiting_list" do
  let(:script) { File.expand_path("../../bin/process_waiting_list", __dir__) }
  let(:root) { Dir.mktmpdir }
  let(:feed_path) { File.join(root, "response.json") }
  let(:waiting_list) do
    RouteFinder::WaitingList.new(File.join(root, "waiting_list"), File.join(root, "notifications"))
  end

  before do
    FileUtils.cp(sample_feed_path, feed_path)
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "moves a search the feed can now serve to notifications and logs the pass" do
    waiting_list.save("CNSHA", "BRSSZ", "cheapest")

    stdout, stderr, status = Open3.capture3({ "FEED_PATH" => feed_path }, RbConfig.ruby, script)

    expect([stdout, stderr, status.exitstatus]).to eq(["", "", 0])
    notification = JSON.parse(File.read(File.join(root, "notifications", "CNSHA_BRSSZ_cheapest.json")))
    expect(notification.map { |leg| leg["sailing_code"] }).to eq(["ERXQ", "ETRB"])
    expect(File.read(File.join(root, "logs", "route_finder.log")))
      .to include("process_waiting_list: Waiting list processed: 1 fulfilled")
  end
end
