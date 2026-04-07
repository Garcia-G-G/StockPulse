# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::Engine do
  subject(:engine) { described_class.new }

  describe "#evaluate_all" do
    let(:user) { create(:user) }
    let!(:alert) { create(:alert, user: user, symbol: "AAPL", alert_type: "price_above", condition: { "value" => 150.0 }) }

    it "evaluates alerts for a symbol and returns triggered results" do
      results = engine.evaluate_all(symbol: "AAPL", price_data: { "price" => 155.0 })
      expect(results.size).to eq(1)
      expect(results.first[:triggered]).to be true
      expect(results.first[:alert]).to eq(alert)
    end

    it "skips alerts on cooldown" do
      alert.update!(last_triggered_at: 5.minutes.ago)
      results = engine.evaluate_all(symbol: "AAPL", price_data: { "price" => 155.0 })
      expect(results).to be_empty
    end

    it "skips inactive alerts" do
      alert.update!(active: false)
      results = engine.evaluate_all(symbol: "AAPL", price_data: { "price" => 155.0 })
      expect(results).to be_empty
    end

    it "returns empty for unmatched symbols" do
      results = engine.evaluate_all(symbol: "MSFT", price_data: { "price" => 300.0 })
      expect(results).to be_empty
    end
  end
end
