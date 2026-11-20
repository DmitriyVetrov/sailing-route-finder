# frozen_string_literal: true

require "spec_helper"

RSpec.describe RouteFinder::Presenter::LegsPresenter do
  let(:rate_book) do
    rate_book_from(
      {
        "ABCD" => ["589.30", "USD"],
        "IJKL" => ["97453", "JPY"],
        "ERXQ" => ["261.96", "EUR"]
      }
    )
  end

  let(:presenter) { RouteFinder::Presenter::LegsPresenter.new(rate_book) }

  def sailing_from_text(code, origin, destination, departure, arrival)
    return sailing(code, origin, destination, Date.iso8601(departure), Date.iso8601(arrival))
  end

  let(:abcd) { sailing_from_text("ABCD", "CNSHA", "NLRTM", "2022-02-01", "2022-03-01") }

  describe "#render" do
    it "prints a leg in the format of the README" do
      legs = JSON.parse(presenter.render([abcd]))

      expect(legs).to eq(
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

    it "keeps the keys in the order of the README" do
      legs = JSON.parse(presenter.render([abcd]))

      expect(legs[0].keys).to eq(
        %w[origin_port destination_port departure_date arrival_date sailing_code rate rate_currency]
      )
    end

    it "echoes the original rate text: the trailing zero of 589.30 survives" do
      text = presenter.render([abcd])

      expect(text).to include('"rate": "589.30"')
    end

    it "does not invent decimals for a currency without them (JPY)" do
      jpy = sailing_from_text("IJKL", "CNSHA", "NLRTM", "2022-01-31", "2022-02-28")

      legs = JSON.parse(presenter.render([jpy]))

      expect(legs[0]["rate"]).to eq("97453")
      expect(legs[0]["rate_currency"]).to eq("JPY")
    end

    it "prints the price in its own currency, not converted to EUR" do
      text = presenter.render([abcd])

      expect(text).not_to include("523.36")
    end

    it "prints several legs in the order they were given" do
      first = sailing_from_text("ERXQ", "CNSHA", "ESBCN", "2022-01-29", "2022-02-12")

      legs = JSON.parse(presenter.render([first, abcd]))

      codes = legs.map { |leg| leg["sailing_code"] }
      expect(codes).to eq(%w[ERXQ ABCD])
    end

    it "prints an empty list as []" do
      expect(presenter.render([])).to eq("[]")
    end

    it "raises when the feed has no rate for a sailing, instead of printing it without a price" do
      unpriced = sailing_from_text("ZZZZ", "CNSHA", "NLRTM", "2022-02-01", "2022-03-01")

      expect { presenter.render([unpriced]) }.to raise_error(
        RouteFinder::RateNotFoundError, /ZZZZ/
      )
    end
  end
end
