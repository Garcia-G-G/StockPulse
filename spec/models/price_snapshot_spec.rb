# frozen_string_literal: true

require "rails_helper"

RSpec.describe PriceSnapshot do
  describe "validations" do
    it { is_expected.to validate_presence_of(:symbol) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_presence_of(:captured_at) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than(0) }
  end

  describe "scopes" do
    let!(:aapl) { create(:price_snapshot, symbol: "AAPL", captured_at: 1.hour.ago) }
    let!(:msft) { create(:price_snapshot, symbol: "MSFT", captured_at: 2.hours.ago) }

    it "filters by symbol" do
      expect(PriceSnapshot.for_symbol("AAPL")).to eq([aapl])
    end

    it "orders by most recent" do
      expect(PriceSnapshot.recent.first).to eq(aapl)
    end

    it "filters older than a time" do
      expect(PriceSnapshot.older_than(30.minutes.ago)).to eq([aapl, msft])
    end
  end

  describe "callbacks" do
    it "upcases symbol" do
      snapshot = build(:price_snapshot, symbol: "aapl")
      snapshot.valid?
      expect(snapshot.symbol).to eq("AAPL")
    end
  end
end
