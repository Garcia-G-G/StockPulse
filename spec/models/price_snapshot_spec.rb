# frozen_string_literal: true

require "rails_helper"

RSpec.describe PriceSnapshot, type: :model do
  describe "validations" do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:close_price) }
    it { should validate_numericality_of(:close_price).is_greater_than(0) }
    it { should validate_numericality_of(:volume).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:timestamp) }
    it { should validate_presence_of(:interval) }
    it { should validate_inclusion_of(:interval).in_array(%w[1m 5m 15m 1h 1d]) }
  end

  describe ".latest_price" do
    it "returns the most recent snapshot for a symbol" do
      create(:price_snapshot, symbol: "AAPL", timestamp: 2.minutes.ago, close_price: 194.0)
      latest = create(:price_snapshot, symbol: "AAPL", timestamp: 1.minute.ago, close_price: 195.5)
      expect(PriceSnapshot.latest_price("AAPL")).to eq(latest)
    end
  end

  describe ".cleanup_old!" do
    it "deletes snapshots older than retention period" do
      create(:price_snapshot, interval: "1m", timestamp: 10.days.ago)
      create(:price_snapshot, interval: "1m", timestamp: 1.day.ago)
      create(:price_snapshot, interval: "1d", timestamp: 30.days.ago)

      PriceSnapshot.cleanup_old!

      expect(PriceSnapshot.by_interval("1m").count).to eq(1)
      expect(PriceSnapshot.by_interval("1d").count).to eq(1)
    end
  end
end
