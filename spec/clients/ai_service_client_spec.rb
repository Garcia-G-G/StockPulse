# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiServiceClient do
  subject(:client) { described_class.new }

  before do
    stub_const("ENV", ENV.to_h.merge({ "AI_SERVICE_URL" => "http://localhost:8001" }))
  end

  describe "initialization" do
    it "sets the base URL from ENV variable" do
      expect(client.base_url).to eq("http://localhost:8001")
    end

    it "uses default URL when ENV variable not set" do
      stub_const("ENV", ENV.to_h.except("AI_SERVICE_URL"))
      client_instance = described_class.new
      expect(client_instance.base_url).to eq("http://localhost:8001")
    end

    it "does not set a rate limit key" do
      expect(client.rate_limit_key).to be_nil
    end
  end

  describe "#analyze" do
    let(:symbol) { "AAPL" }
    let(:price_data) do
      {
        "current_price" => 150.25,
        "open" => 149.10,
        "high" => 151.50,
        "low" => 148.75,
        "close" => 150.25,
        "volume" => 75_000_000,
        "pe_ratio" => 28.5
      }
    end
    let(:technical_data) do
      {
        "rsi" => 72.5,
        "macd" => 5.2345,
        "macd_signal" => 4.7778,
        "sma_50" => 149.8,
        "sma_200" => 145.2,
        "bollinger_upper" => 152.5,
        "bollinger_lower" => 147.9
      }
    end
    let(:news_data) do
      [
        {
          "title" => "Apple reports record earnings",
          "source" => "Reuters",
          "sentiment" => "positive",
          "published_at" => "2026-04-06T18:00:00.000Z"
        }
      ]
    end
    let(:response_body) do
      {
        "symbol" => symbol,
        "recommendation" => "BUY",
        "confidence" => 0.85,
        "analysis" => {
          "price_trend" => "uptrend",
          "technical_signals" => "bullish",
          "sentiment" => "positive",
          "risk_level" => "medium"
        },
        "target_price" => 165.50,
        "stop_loss" => 140.00,
        "summary" => "Strong buying signals based on technical analysis and positive news sentiment."
      }
    end

    context "with valid data" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .with(
            body: hash_including(
              symbol: symbol,
              price_data: price_data,
              technical_data: technical_data,
              news_data: news_data
            )
          )
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns analysis result" do
        result = client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
        expect(result["recommendation"]).to eq("BUY")
        expect(result["confidence"]).to eq(0.85)
      end

      it "includes target price and stop loss" do
        result = client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
        expect(result["target_price"]).to eq(165.50)
        expect(result["stop_loss"]).to eq(140.00)
      end

      it "includes detailed analysis breakdown" do
        result = client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
        expect(result["analysis"]).to include(
          "price_trend",
          "technical_signals",
          "sentiment",
          "risk_level"
        )
      end

      it "includes summary" do
        result = client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
        expect(result["summary"]).to include("Strong buying signals")
      end
    end

    context "with SELL recommendation" do
      let(:sell_response) do
        {
          "symbol" => symbol,
          "recommendation" => "SELL",
          "confidence" => 0.78,
          "analysis" => {
            "price_trend" => "downtrend",
            "technical_signals" => "bearish",
            "sentiment" => "negative",
            "risk_level" => "high"
          },
          "target_price" => 140.00,
          "stop_loss" => 155.00,
          "summary" => "Bearish signals indicate time to sell."
        }
      end

      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_return(status: 200, body: sell_response.to_json)
      end

      it "returns SELL recommendation" do
        result = client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
        expect(result["recommendation"]).to eq("SELL")
      end
    end

    context "with HOLD recommendation" do
      let(:hold_response) do
        {
          "symbol" => symbol,
          "recommendation" => "HOLD",
          "confidence" => 0.65,
          "analysis" => {
            "price_trend" => "sideways",
            "technical_signals" => "neutral",
            "sentiment" => "mixed",
            "risk_level" => "low"
          },
          "target_price" => nil,
          "stop_loss" => nil,
          "summary" => "Insufficient signals for action. Wait for clearer signals."
        }
      end

      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_return(status: 200, body: hold_response.to_json)
      end

      it "returns HOLD recommendation" do
        result = client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
        expect(result["recommendation"]).to eq("HOLD")
      end
    end
  end

  describe "#health" do
    context "when service is healthy" do
      before do
        stub_request(:get, "http://localhost:8001/health")
          .to_return(status: 200, body: { "status" => "healthy", "version" => "1.0.0" }.to_json)
      end

      it "returns health status" do
        result = client.health
        expect(result["status"]).to eq("healthy")
      end

      it "includes version information" do
        result = client.health
        expect(result["version"]).to be_present
      end
    end

    context "when service is unhealthy" do
      before do
        stub_request(:get, "http://localhost:8001/health")
          .to_return(status: 503, body: { "status" => "unhealthy", "error" => "Database connection failed" }.to_json)
      end

      it "raises ServiceUnavailable error" do
        expect { client.health }.to raise_error(Faraday::ServiceUnavailable)
      end
    end

    context "when service is unreachable" do
      before do
        stub_request(:get, "http://localhost:8001/health")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "raises ConnectionFailed error" do
        expect { client.health }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "request body serialization" do
    let(:symbol) { "MSFT" }
    let(:price_data) { { "current_price" => 300.0 } }
    let(:technical_data) { { "rsi" => 65.0 } }
    let(:news_data) { [] }
    let(:response_body) do
      {
        "symbol" => symbol,
        "recommendation" => "BUY",
        "confidence" => 0.75,
        "analysis" => {},
        "target_price" => 310.0,
        "stop_loss" => 290.0,
        "summary" => "Test summary"
      }
    end

    before do
      stub_request(:post, "http://localhost:8001/analyze")
        .to_return(status: 200, body: response_body.to_json)
    end

    it "sends correct request body structure" do
      client.analyze(
        symbol: symbol,
        price_data: price_data,
        technical_data: technical_data,
        news_data: news_data
      )

      expect(WebMock).to have_requested(:post, "http://localhost:8001/analyze")
        .with(body: hash_including(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        ))
    end

    it "handles empty news data" do
      client.analyze(
        symbol: symbol,
        price_data: price_data,
        technical_data: technical_data,
        news_data: []
      )

      expect(WebMock).to have_requested(:post, "http://localhost:8001/analyze")
        .with(body: hash_including(news_data: []))
    end

    it "handles complex nested data structures" do
      complex_price_data = {
        "ohlc" => { "o" => 1.0, "h" => 2.0, "l" => 0.5, "c" => 1.5 },
        "volume" => 1_000_000,
        "advanced_metrics" => { "pe" => 20.0, "pb" => 1.5 }
      }

      stub_request(:post, "http://localhost:8001/analyze")
        .to_return(status: 200, body: response_body.to_json)

      client.analyze(
        symbol: symbol,
        price_data: complex_price_data,
        technical_data: technical_data,
        news_data: news_data
      )

      expect(WebMock).to have_requested(:post, "http://localhost:8001/analyze")
        .with(body: hash_including(price_data: complex_price_data))
    end
  end

  describe "error handling" do
    let(:symbol) { "AAPL" }
    let(:price_data) { { "current_price" => 150.0 } }
    let(:technical_data) { { "rsi" => 70.0 } }
    let(:news_data) { [] }

    context "when service returns 400 bad request" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_return(status: 400, body: { "error" => "Invalid price data format" }.to_json)
      end

      it "raises BadRequest error" do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::BadRequestError)
      end
    end

    context "when service returns 422 unprocessable entity" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_return(status: 422, body: { "error" => "Unable to process analysis request" }.to_json)
      end

      it "raises UnprocessableEntity error" do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::UnprocessableEntityError)
      end
    end

    context "when service returns 500 server error" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_return(status: 500, body: { "error" => "Internal server error" }.to_json)
      end

      it "raises InternalServerError" do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::InternalServerError)
      end
    end

    context "when service returns 503 service unavailable" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_return(status: 503, body: { "error" => "Service temporarily unavailable" }.to_json)
      end

      it "raises ServiceUnavailable error" do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::ServiceUnavailable)
      end
    end
  end

  describe "circuit breaker" do
    let(:symbol) { "AAPL" }
    let(:price_data) { { "current_price" => 150.0 } }
    let(:technical_data) { { "rsi" => 70.0 } }
    let(:news_data) { [] }

    before do
      stub_request(:post, "http://localhost:8001/analyze")
        .to_return(status: 500)
    end

    it "opens circuit after 5 consecutive failures" do
      5.times do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::InternalServerError)
      end

      # Next request should fail with CircuitOpenError
      expect {
        client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
      }.to raise_error(BaseClient::CircuitOpenError)
    end

    it "resets circuit on successful request" do
      stub_request(:post, "http://localhost:8001/analyze")
        .to_return(status: 200, body: {
          "symbol" => symbol,
          "recommendation" => "BUY",
          "confidence" => 0.85,
          "analysis" => {},
          "target_price" => 160.0,
          "stop_loss" => 140.0,
          "summary" => "Test"
        }.to_json)

      client.analyze(
        symbol: symbol,
        price_data: price_data,
        technical_data: technical_data,
        news_data: news_data
      )
      expect {
        client.analyze(
          symbol: symbol,
          price_data: price_data,
          technical_data: technical_data,
          news_data: news_data
        )
      }.not_to raise_error(BaseClient::CircuitOpenError)
    end
  end

  describe "retry behavior" do
    let(:symbol) { "AAPL" }
    let(:price_data) { { "current_price" => 150.0 } }
    let(:technical_data) { { "rsi" => 70.0 } }
    let(:news_data) { [] }

    context "when request times out" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_timeout
      end

      it "retries the request and raises TimeoutError" do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::TimeoutError)
      end
    end

    context "when request fails with connection error" do
      before do
        stub_request(:post, "http://localhost:8001/analyze")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "retries the request and raises ConnectionFailed" do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "no rate limiting" do
    let(:symbol) { "AAPL" }
    let(:price_data) { { "current_price" => 150.0 } }
    let(:technical_data) { { "rsi" => 70.0 } }
    let(:news_data) { [] }
    let(:response_body) do
      {
        "symbol" => symbol,
        "recommendation" => "BUY",
        "confidence" => 0.85,
        "analysis" => {},
        "target_price" => 160.0,
        "stop_loss" => 140.0,
        "summary" => "Test"
      }
    end

    before do
      stub_request(:post, "http://localhost:8001/analyze")
        .to_return(status: 200, body: response_body.to_json)
    end

    it "does not apply rate limiting" do
      # Make multiple rapid requests without hitting rate limit
      3.times do
        expect {
          client.analyze(
            symbol: symbol,
            price_data: price_data,
            technical_data: technical_data,
            news_data: news_data
          )
        }.not_to raise_error(BaseClient::RateLimitExceeded)
      end
    end
  end

  describe "recommendation confidence levels" do
    let(:symbol) { "AAPL" }
    let(:price_data) { { "current_price" => 150.0 } }
    let(:technical_data) { { "rsi" => 70.0 } }
    let(:news_data) { [] }

    %w[BUY SELL HOLD].each do |recommendation|
      context "with #{recommendation} recommendation" do
        (0.5..1.0).step(0.1).each do |confidence|
          it "returns #{recommendation} with confidence #{confidence}" do
            response_body = {
              "symbol" => symbol,
              "recommendation" => recommendation,
              "confidence" => confidence,
              "analysis" => {},
              "target_price" => 160.0,
              "stop_loss" => 140.0,
              "summary" => "Test"
            }

            stub_request(:post, "http://localhost:8001/analyze")
              .to_return(status: 200, body: response_body.to_json)

            result = client.analyze(
              symbol: symbol,
              price_data: price_data,
              technical_data: technical_data,
              news_data: news_data
            )

            expect(result["recommendation"]).to eq(recommendation)
            expect(result["confidence"]).to eq(confidence)
          end
        end
      end
    end
  end
end
