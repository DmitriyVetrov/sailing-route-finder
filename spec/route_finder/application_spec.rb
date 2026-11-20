# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# The composition root, built from a copy of the sample feed in a temporary directory so
# the waiting list and the log never touch data/.
RSpec.describe RouteFinder::Application do
  let(:root) { Dir.mktmpdir }
  let(:feed_path) { File.join(root, "response.json") }
  let(:log_path) { File.join(root, "logs", "route_finder.log") }

  before do
    FileUtils.cp(sample_feed_path, feed_path)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe ".feed_path_from" do
    it "takes FEED_PATH when it is set" do
      expect(RouteFinder::Application.feed_path_from({ "FEED_PATH" => "/feeds/today.json" }))
        .to eq("/feeds/today.json")
    end

    it "falls back to the bundled sample feed" do
      expect(RouteFinder::Application.feed_path_from({})).to eq(sample_feed_path)
    end
  end

  describe "a working application" do
    let(:app) { RouteFinder::Application.new(feed_path, "spec") }

    it "builds a factory that answers the README searches" do
      route = app.factory.build("cheapest").find_route("CNSHA", "NLRTM")

      expect(codes_of(route)).to eq(["ERXQ", "ETRG"])
    end

    it "keeps the waiting list next to the feed" do
      app.waiting_list.save("CNSHA", "BRSSZ", "cheapest-direct")

      expect(File.exist?(File.join(root, "waiting_list", "CNSHA_BRSSZ_cheapest-direct.json"))).to be(true)
    end

    it "writes the log next to the feed, tagged with the program name" do
      app.logger.info("hello")

      expect(File.read(log_path)).to include("INFO -- spec: hello")
    end
  end

  it "survives a broken feed: no sailings, and the reason is in the log" do
    File.write(feed_path, "{ broken")

    app = RouteFinder::Application.new(feed_path, "spec")

    expect(app.factory.build("fastest").find_route("CNSHA", "NLRTM")).to eq([])
    expect(File.read(log_path)).to include("Feed is not valid JSON")
  end
end
