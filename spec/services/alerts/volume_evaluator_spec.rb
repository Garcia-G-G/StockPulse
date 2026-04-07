# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::VolumeEvaluator do
  subject(:evaluator) { described_class.new }

  describe "#evaluate" do
    let(:alert) { build(:alert, :volume_spike, symbol: "AAPL") }

    before do
      20.times do |i|
        create(:price_snapshot, symbol: "AAPL", volume: 50_000_000, captured_at: (i + 1).days.ago)
      end
    end

    it "triggers when volume exceeds threshold percentage of average" do
      result = evaluator.evaluate(alert, price_data: { "volume" => 110_000_000 })
      expect(result[:triggered]).to be true
      expect(result[:message]).to include("volume spike")
    end

    it "does not trigger when volume is normal" do
      result = evaluator.evaluate(alert, price_data: { "volume" => 50_000_000 })
      expect(result).to be_nil
    end

    it "returns nil when no historical data" do
      PriceSnapshot.delete_all
      result = evaluator.evaluate(alert, price_data: { "volume" => 100_000_000 })
      expect(result).to be_nil
    end

    it "returns nil when volume is zero" do
      result = evaluator.evaluate(alert, price_data: { "volume" => 0 })
      expect(result).to be_nil
    end
  end
end
