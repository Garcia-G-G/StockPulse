# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiServiceClient, type: :client do
  let(:client) { described_class.new }

  describe "#analyze_price" do
    it "returns fallback on connection refused" do
      stub_request(:post, /localhost:8001.*analyze/)
        .to_raise(Faraday::ConnectionFailed)

      result = client.analyze_price(symbol: "AAPL", current_price: 195.5, previous_close: 194.0, change_percent: 0.77)
      expect(result[:error]).to be true
      expect(result[:fallback]).to be true
    end
  end

  describe "#health" do
    it "returns fallback when service unavailable" do
      stub_request(:get, /localhost:8001.*health/)
        .to_raise(Faraday::ConnectionFailed)

      result = client.health
      expect(result[:error]).to be true
    end
  end
end
