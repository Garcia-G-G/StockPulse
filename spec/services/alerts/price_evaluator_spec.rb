# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::PriceEvaluator do
  subject(:evaluator) { described_class.new }

  describe "#evaluate" do
    context "price_above" do
      let(:alert) { build(:alert, symbol: "AAPL", alert_type: "price_above", condition: { "value" => 150.0 }) }

      it "triggers when price is above target" do
        result = evaluator.evaluate(alert, price_data: { "price" => 155.0 })
        expect(result[:triggered]).to be true
        expect(result[:message]).to include("AAPL")
        expect(result[:message]).to include("above")
      end

      it "does not trigger when price is below target" do
        result = evaluator.evaluate(alert, price_data: { "price" => 145.0 })
        expect(result).to be_nil
      end

      it "triggers at exact target" do
        result = evaluator.evaluate(alert, price_data: { "price" => 150.0 })
        expect(result[:triggered]).to be true
      end
    end

    context "price_below" do
      let(:alert) { build(:alert, :price_below, symbol: "AAPL") }

      it "triggers when price drops below target" do
        result = evaluator.evaluate(alert, price_data: { "price" => 95.0 })
        expect(result[:triggered]).to be true
        expect(result[:message]).to include("below")
      end

      it "does not trigger when price is above target" do
        result = evaluator.evaluate(alert, price_data: { "price" => 105.0 })
        expect(result).to be_nil
      end
    end

    context "price_change_pct" do
      let(:alert) { build(:alert, :percent_change, symbol: "AAPL") }

      it "triggers when percent change exceeds threshold" do
        result = evaluator.evaluate(alert, price_data: { "price" => 155.0, "change_percent" => 6.0 })
        expect(result[:triggered]).to be true
        expect(result[:message]).to include("up")
      end

      it "triggers for negative change" do
        result = evaluator.evaluate(alert, price_data: { "price" => 140.0, "change_percent" => -6.0 })
        expect(result[:triggered]).to be true
        expect(result[:message]).to include("down")
      end

      it "does not trigger when below threshold" do
        result = evaluator.evaluate(alert, price_data: { "price" => 150.0, "change_percent" => 2.0 })
        expect(result).to be_nil
      end
    end

    it "returns nil when no price data" do
      alert = build(:alert, alert_type: "price_above", condition: { "value" => 150.0 })
      result = evaluator.evaluate(alert, price_data: {})
      expect(result).to be_nil
    end
  end
end
