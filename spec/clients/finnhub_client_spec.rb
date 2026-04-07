# frozen_string_literal: true

require "rails_helper"

RSpec.describe FinnhubClient do
  subject(:client) { described_class.new }

  before do
    stub_const("FinnhubConfig::API_KEY", "test_api_key")
    stub_const("FinnhubConfig::RATE_LIMIT_PER_MIN", 60)
  end

  describe "initialization" do
    it "sets the base URL to Finnhub API v1" do
      expect(client.base_url).to eq("https://finnhub.io/api/v1")
    end

    it "sets rate limit key to finnhub" do
      expect(client.rate_limit_key).to eq("finnhub")
    end

    it "sets rate limit to 60 requests per minute" do
      expect(client.rate_limit_max).to eq(60)
      expect(client.rate_limit_period).to eq(60)
    end
  end

  describe "#quote" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "c" => 150.25,
        "d" => 2.15,
        "dp" => 1.45,
        "h" => 151.50,
        "l" => 148.75,
        "o" => 149.10,
        "pc" => 148.10,
        "t" => 1_609_459_200
      }
    end

    context "when API returns successful response" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/quote")
          .with(query: hash_including(symbol: symbol, token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns quote data" do
        result = client.quote(symbol)
        expect(result["c"]).to eq(150.25)
        expect(result["d"]).to eq(2.15)
      end

      it "includes current price and change" do
        result = client.quote(symbol)
        expect(result).to include("c", "d", "dp")
      end
    end

    context "when API returns 404 for invalid symbol" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/quote")
          .with(query: hash_including(symbol: "INVALID"))
          .to_return(status: 404, body: { "error" => "Symbol not found" }.to_json)
      end

      it "raises an error" do
        expect { client.quote("INVALID") }.to raise_error(Faraday::ResourceNotFound)
      end
    end

    context "when API is down" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/quote")
          .to_return(status: 503, body: "Service Unavailable")
      end

      it "raises ServiceUnavailable error" do
        expect { client.quote(symbol) }.to raise_error(Faraday::ServiceUnavailable)
      end

      it "records circuit failure" do
        expect { client.quote(symbol) }.to raise_error(Faraday::ServiceUnavailable)
        # After 5 failures, circuit should open
        4.times do
          expect { client.quote(symbol) }.to raise_error(Faraday::ServiceUnavailable)
        end
        expect { client.quote(symbol) }.to raise_error(BaseClient::CircuitOpenError)
      end
    end
  end

  describe "#company_profile" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "country" => "US",
        "currency" => "USD",
        "exchange" => "NASDAQ",
        "ipo" => "1980-12-12",
        "name" => "Apple Inc",
        "phone" => "1-408-996-1010",
        "sector" => "Technology",
        "ticker" => "AAPL",
        "weburl" => "https://www.apple.com/"
      }
    end

    context "when API returns successful response" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/stock/profile2")
          .with(query: hash_including(symbol: symbol, token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns company profile data" do
        result = client.company_profile(symbol)
        expect(result["name"]).to eq("Apple Inc")
        expect(result["ticker"]).to eq("AAPL")
        expect(result["country"]).to eq("US")
      end

      it "includes required profile fields" do
        result = client.company_profile(symbol)
        expect(result).to include("country", "currency", "exchange", "name", "sector")
      end
    end
  end

  describe "#financials" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "metric" => {
          "10DayAverageTradingVolume" => 75_000_000,
          "52WeekHigh" => 175.15,
          "52WeekLow" => 130.25,
          "beta" => 1.2,
          "marketCapitalization" => 2_800_000_000_000,
          "peRatio" => 28.5,
          "profitMargin" => 0.25
        },
        "series" => {},
        "symbol" => "AAPL"
      }
    end

    context "when API returns successful response" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/stock/metric")
          .with(query: hash_including(symbol: symbol, metric: "all", token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns financial metrics" do
        result = client.financials(symbol)
        expect(result["metric"]).to include("peRatio", "beta", "marketCapitalization")
      end

      it "includes valuation metrics" do
        result = client.financials(symbol)
        expect(result["metric"]["peRatio"]).to eq(28.5)
        expect(result["metric"]["beta"]).to eq(1.2)
      end
    end
  end

  describe "#news" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      [
        {
          "category" => "company news",
          "datetime" => 1_609_459_200,
          "headline" => "Apple reports record Q4 revenue",
          "id" => 123_456,
          "image" => "https://example.com/image.jpg",
          "related" => "AAPL",
          "source" => "Reuters",
          "summary" => "Apple reported record revenue in Q4 2024",
          "url" => "https://example.com/article"
        }
      ]
    end

    context "with default date range (last 7 days)" do
      before do
        allow(Date).to receive(:today).and_return(Date.new(2026, 4, 6))
        stub_request(:get, "https://finnhub.io/api/v1/company-news")
          .with(query: hash_including(symbol: symbol, token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns news articles" do
        result = client.news(symbol)
        expect(result).to be_an(Array)
        expect(result.first["headline"]).to eq("Apple reports record Q4 revenue")
      end

      it "includes article metadata" do
        result = client.news(symbol)
        expect(result.first).to include("headline", "source", "url", "datetime")
      end
    end

    context "with custom date range" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/company-news")
          .with(query: hash_including(symbol: symbol, from: "2026-01-01", to: "2026-04-06", token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns news for specified date range" do
        result = client.news(symbol, from: "2026-01-01", to: "2026-04-06")
        expect(result).to be_an(Array)
      end
    end
  end

  describe "#search" do
    let(:query) { "Apple" }
    let(:response_body) do
      {
        "count" => 10,
        "result" => [
          {
            "description" => "Apple Inc - USD (NASDAQ)",
            "displaySymbol" => "AAPL",
            "symbol" => "AAPL",
            "type" => "Common Stock"
          },
          {
            "description" => "Apple Hospitality REIT Inc - USD (NYSE)",
            "displaySymbol" => "APLE",
            "symbol" => "APLE",
            "type" => "Common Stock"
          }
        ]
      }
    end

    context "when API returns successful response" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/search")
          .with(query: hash_including(q: query, token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns search results" do
        result = client.search(query)
        expect(result["result"]).to be_an(Array)
        expect(result["result"].length).to eq(2)
      end

      it "includes symbol information" do
        result = client.search(query)
        expect(result["result"].first["displaySymbol"]).to eq("AAPL")
        expect(result["result"].first["description"]).to include("Apple Inc")
      end
    end
  end

  describe "#market_status" do
    let(:response_body) do
      {
        "isOpen" => true,
        "session" => "extended-hours"
      }
    end

    context "when market is open" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/stock/market-status")
          .with(query: hash_including(exchange: "US", token: "test_api_key"))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns market status" do
        result = client.market_status
        expect(result["isOpen"]).to eq(true)
      end
    end
  end

  describe "rate limiting" do
    let(:symbol) { "AAPL" }
    let(:response_body) { { "c" => 150.25 }.to_json }

    before do
      stub_request(:get, "https://finnhub.io/api/v1/quote")
        .to_return(status: 200, body: response_body)
    end

    context "when rate limit is not exceeded" do
      it "allows requests under the limit" do
        expect { client.quote(symbol) }.not_to raise_error
      end
    end

    context "when rate limit is exceeded" do
      before do
        allow_any_instance_of(BaseClient).to receive(:check_rate_limit!).and_call_original
        allow(REDIS_POOL).to receive(:with).and_yield(redis_mock)
      end

      let(:redis_mock) do
        double.tap do |mock|
          allow(mock).to receive(:get).and_return("60")
          allow(mock).to receive(:multi).and_yield(mock)
          allow(mock).to receive(:incr)
          allow(mock).to receive(:expire)
        end
      end

      it "raises RateLimitExceeded error" do
        expect { client.quote(symbol) }.to raise_error(BaseClient::RateLimitExceeded)
      end
    end
  end

  describe "circuit breaker" do
    let(:symbol) { "AAPL" }

    before do
      stub_request(:get, "https://finnhub.io/api/v1/quote")
        .to_return(status: 503)
    end

    it "opens circuit after 5 consecutive failures" do
      5.times do |i|
        expect { client.quote(symbol) }.to raise_error(Faraday::ServiceUnavailable)
      end

      # Next request should fail with CircuitOpenError
      expect { client.quote(symbol) }.to raise_error(BaseClient::CircuitOpenError)
    end

    it "resets circuit on successful request" do
      stub_request(:get, "https://finnhub.io/api/v1/quote")
        .to_return(status: 200, body: { "c" => 150.25 }.to_json)

      client.quote(symbol)
      expect { client.quote(symbol) }.not_to raise_error(BaseClient::CircuitOpenError)
    end
  end

  describe "retry behavior" do
    let(:symbol) { "AAPL" }
    let(:response_body) { { "c" => 150.25 }.to_json }

    context "when request times out" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/quote")
          .to_timeout
      end

      it "retries the request" do
        expect { client.quote(symbol) }.to raise_error(Faraday::TimeoutError)
        expect(WebMock).to have_requested(:get, "https://finnhub.io/api/v1/quote")
      end
    end

    context "when request fails with connection error" do
      before do
        stub_request(:get, "https://finnhub.io/api/v1/quote")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "retries the request" do
        expect { client.quote(symbol) }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "request parameters" do
    let(:symbol) { "AAPL" }
    let(:response_body) { { "c" => 150.25 }.to_json }

    before do
      stub_request(:get, "https://finnhub.io/api/v1/quote")
        .to_return(status: 200, body: response_body)
    end

    it "includes API key in quote requests" do
      client.quote(symbol)
      expect(WebMock).to have_requested(:get, "https://finnhub.io/api/v1/quote")
        .with(query: hash_including(token: "test_api_key"))
    end

    it "includes symbol parameter in company profile requests" do
      stub_request(:get, "https://finnhub.io/api/v1/stock/profile2")
        .to_return(status: 200, body: response_body)

      client.company_profile(symbol)
      expect(WebMock).to have_requested(:get, "https://finnhub.io/api/v1/stock/profile2")
        .with(query: hash_including(symbol: symbol))
    end

    it "includes all required metrics in financial requests" do
      stub_request(:get, "https://finnhub.io/api/v1/stock/metric")
        .to_return(status: 200, body: response_body)

      client.financials(symbol)
      expect(WebMock).to have_requested(:get, "https://finnhub.io/api/v1/stock/metric")
        .with(query: hash_including(metric: "all"))
    end
  end
end
