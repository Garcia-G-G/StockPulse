# frozen_string_literal: true

require "rails_helper"

RSpec.describe Streaming::TradeAggregator, type: :service do
  let(:aggregator) { described_class.new }

  describe "#process_trades" do
    let(:now_ms) { (Time.current.to_f * 1000).to_i }

    it "aggregates trades into OHLCV windows" do
      trades = [
        { s: "AAPL", p: 195.0, v: 100, t: now_ms },
        { s: "AAPL", p: 196.5, v: 200, t: now_ms },
        { s: "AAPL", p: 194.0, v: 150, t: now_ms },
        { s: "AAPL", p: 195.5, v: 250, t: now_ms }
      ]

      aggregator.process_trades(trades)
      windows = aggregator.instance_variable_get(:@windows)
      w = windows["AAPL"]

      expect(w[:open]).to eq(195.0)
      expect(w[:high]).to eq(196.5)
      expect(w[:low]).to eq(194.0)
      expect(w[:close]).to eq(195.5)
      expect(w[:trade_count]).to eq(4)
    end

    it "calculates correct VWAP" do
      trades = [
        { s: "AAPL", p: 100.0, v: 100, t: now_ms },
        { s: "AAPL", p: 200.0, v: 100, t: now_ms }
      ]

      aggregator.process_trades(trades)
      w = aggregator.instance_variable_get(:@windows)["AAPL"]
      vwap = (w[:vwap_numerator] / w[:vwap_denominator]).round(4)
      expect(vwap).to eq(150.0) # (100*100 + 200*100) / 200
    end
  end
end
