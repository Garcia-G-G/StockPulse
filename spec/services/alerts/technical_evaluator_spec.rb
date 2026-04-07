# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::TechnicalEvaluator do
  subject(:evaluator) { described_class.new }

  let(:price_data) { { "price" => 150.0 } }

  describe "#evaluate" do
    context "rsi_overbought" do
      let(:alert) { build(:alert, :rsi_overbought, symbol: "AAPL") }

      it "triggers when RSI above threshold" do
        result = evaluator.evaluate(alert, price_data: price_data, technical_data: { "rsi" => 75.0 })
        expect(result[:triggered]).to be true
        expect(result[:message]).to include("overbought")
      end

      it "does not trigger when RSI below threshold" do
        result = evaluator.evaluate(alert, price_data: price_data, technical_data: { "rsi" => 50.0 })
        expect(result).to be_nil
      end
    end

    context "rsi_oversold" do
      let(:alert) { build(:alert, :rsi_oversold, symbol: "AAPL") }

      it "triggers when RSI below threshold" do
        result = evaluator.evaluate(alert, price_data: price_data, technical_data: { "rsi" => 25.0 })
        expect(result[:triggered]).to be true
        expect(result[:message]).to include("oversold")
      end
    end

    context "macd_crossover" do
      let(:alert) { build(:alert, :macd_crossover, symbol: "AAPL") }

      it "triggers on bullish crossover" do
        technical_data = { "macd" => { "MACD" => 0.5, "MACD_Signal" => 0.3, "MACD_Hist" => 0.2, "MACD_Hist_Prev" => -0.1 } }
        result = evaluator.evaluate(alert, price_data: price_data, technical_data: technical_data)
        expect(result[:triggered]).to be true
        expect(result[:data][:crossover]).to eq("bullish")
      end

      it "triggers on bearish crossover" do
        technical_data = { "macd" => { "MACD" => -0.5, "MACD_Signal" => -0.3, "MACD_Hist" => -0.2, "MACD_Hist_Prev" => 0.1 } }
        result = evaluator.evaluate(alert, price_data: price_data, technical_data: technical_data)
        expect(result[:triggered]).to be true
        expect(result[:data][:crossover]).to eq("bearish")
      end
    end

    context "bollinger_breakout" do
      let(:alert) { build(:alert, :bollinger_breakout, symbol: "AAPL") }

      it "triggers when price above upper band" do
        technical_data = { "bollinger" => { "upper" => 155.0, "lower" => 145.0, "middle" => 150.0 } }
        result = evaluator.evaluate(alert, price_data: { "price" => 156.0 }, technical_data: technical_data)
        expect(result[:triggered]).to be true
        expect(result[:data][:breakout]).to eq("above")
      end

      it "triggers when price below lower band" do
        technical_data = { "bollinger" => { "upper" => 155.0, "lower" => 145.0, "middle" => 150.0 } }
        result = evaluator.evaluate(alert, price_data: { "price" => 144.0 }, technical_data: technical_data)
        expect(result[:triggered]).to be true
        expect(result[:data][:breakout]).to eq("below")
      end
    end

    it "returns nil when no technical data" do
      alert = build(:alert, :rsi_overbought)
      result = evaluator.evaluate(alert, price_data: price_data, technical_data: nil)
      expect(result).to be_nil
    end
  end
end
