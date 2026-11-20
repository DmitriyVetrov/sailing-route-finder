# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# WaitingList (saved searches) against real files in a temporary directory and the real
# sample feed: the class is a file store, so faking the file system would test nothing.
RSpec.describe RouteFinder::WaitingList do
  let(:root) { Dir.mktmpdir }
  let(:waiting_dir) { File.join(root, "waiting_list") }
  let(:notifications_dir) { File.join(root, "notifications") }
  let(:waiting_list) { RouteFinder::WaitingList.new(waiting_dir, notifications_dir) }

  after do
    FileUtils.rm_rf(root)
  end

  # Built from the real feed, exactly as Application does.
  let(:loader) { load_sample_feed }
  let(:factory) { RouteFinder::CriteriaFactory.new(loader.sailings, cost_calculator_for(loader)) }
  let(:presenter) { RouteFinder::Presenter::LegsPresenter.new(loader.rate_book) }
  let(:logger_and_output) { capturing_logger }
  let(:logger) { logger_and_output[0] }
  let(:log) { logger_and_output[1] }

  def read_json(path)
    return JSON.parse(File.read(path))
  end

  describe "#save" do
    it "writes the request into <ORIGIN>_<DEST>_<criteria>.json and returns the name" do
      file_name = waiting_list.save("CNSHA", "BRSSZ", "cheapest")

      expect(file_name).to eq("CNSHA_BRSSZ_cheapest.json")
      saved = read_json(File.join(waiting_dir, file_name))
      expect(saved).to eq(
        "origin_port" => "CNSHA",
        "destination_port" => "BRSSZ",
        "criteria" => "cheapest"
      )
    end

    it "overwrites the same file when the same search is saved again" do
      waiting_list.save("CNSHA", "BRSSZ", "cheapest")
      waiting_list.save("CNSHA", "BRSSZ", "cheapest")

      expect(Dir.children(waiting_dir)).to eq(["CNSHA_BRSSZ_cheapest.json"])
    end

    it "refuses a port that would escape the directory, and writes nothing" do
      expect { waiting_list.save("../../etc", "NLRTM", "cheapest") }
        .to raise_error(RouteFinder::InvalidSearchRequestError)

      expect(Dir.exist?(waiting_dir)).to be(false)
    end
  end

  describe "#process" do
    it "moves a request that now has a route to notifications, with the README output inside" do
      waiting_list.save("CNSHA", "NLRTM", "cheapest-direct")

      fulfilled = waiting_list.process(factory, presenter, logger)

      expect(fulfilled).to eq(["CNSHA_NLRTM_cheapest-direct.json"])
      expect(Dir.children(waiting_dir)).to be_empty

      notification = File.read(File.join(notifications_dir, "CNSHA_NLRTM_cheapest-direct.json"))
      expected = presenter.render(factory.build("cheapest-direct").find_route("CNSHA", "NLRTM"))
      expect(notification).to eq(expected + "\n")
    end

    it "logs every fulfilled request" do
      waiting_list.save("CNSHA", "NLRTM", "cheapest-direct")

      waiting_list.process(factory, presenter, logger)

      expect(log.string).to include("Fulfilled CNSHA_NLRTM_cheapest-direct.json: moved to notifications")
    end

    it "leaves a request that still has no route where it is" do
      waiting_list.save("XXXXX", "NLRTM", "cheapest")

      fulfilled = waiting_list.process(factory, presenter, logger)

      expect(fulfilled).to be_empty
      expect(Dir.children(waiting_dir)).to eq(["XXXXX_NLRTM_cheapest.json"])
      expect(Dir.exist?(notifications_dir)).to be(false)
    end

    it "produces nothing new on a second pass" do
      waiting_list.save("CNSHA", "NLRTM", "cheapest-direct")
      waiting_list.process(factory, presenter, logger)

      second_pass = waiting_list.process(factory, presenter, logger)

      expect(second_pass).to be_empty
      expect(Dir.children(notifications_dir)).to eq(["CNSHA_NLRTM_cheapest-direct.json"])
    end

    it "skips a corrupt request file, logs it, and still processes the others" do
      FileUtils.mkdir_p(waiting_dir)
      File.write(File.join(waiting_dir, "BROKEN.json"), "this is not json")
      waiting_list.save("CNSHA", "NLRTM", "cheapest-direct")

      fulfilled = waiting_list.process(factory, presenter, logger)

      expect(fulfilled).to eq(["CNSHA_NLRTM_cheapest-direct.json"])
      expect(log.string).to include("Skipped waiting-list file BROKEN.json")
      expect(Dir.children(waiting_dir)).to eq(["BROKEN.json"])
    end

    it "does nothing when the waiting list directory does not exist yet" do
      fulfilled = waiting_list.process(factory, presenter, logger)

      expect(fulfilled).to be_empty
    end
  end
end
