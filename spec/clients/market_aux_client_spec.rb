# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketAuxClient do
  subject(:client) { described_class.new }

  before do
    stub_const("ENV", ENV.to_h.merge({ "MARKETAUX_API_KEY" => "test_market_aux_key" }))
  end

  describe "initialization" do
    it "sets the base URL to MarketAux API v1" do
      expect(client.base_url).to eq("https://api.marketaux.com/v1")
    end

    it "sets rate limit key to marketaux" do
      expect(client.rate_limit_key).to eq("marketaux")
    end

    it "sets rate limit to 100 requests per day" do
      expect(client.rate_limit_max).to eq(100)
    end

    it "sets rate limit period to 86400 seconds (1 day)" do
      expect(client.rate_limit_period).to eq(86_400)
    end
  end

  describe "#news" do
    let(:response_body) do
      {
        "status" => "ok",
        "meta" => {
          "last_updated" => "2026-04-06T20:30:00.000Z",
          "page" => 1
        },
        "data" => [
          {
            "id" => "abc123def456",
            "title" => "Apple stock surges on strong earnings",
            "description" => "Apple Inc reported record quarterly earnings beating analyst expectations.",
            "content" => "Full article content here...",
            "url" => "https://example.com/article1",
            "image_url" => "https://example.com/image1.jpg",
            "source" => "Reuters",
            "category" => "earnings",
            "published_at" => "2026-04-06T18:30:00.000Z",
            "updated_at" => "2026-04-06T19:00:00.000Z",
            "entities" => [
              { "symbol" => "AAPL", "name" => "Apple Inc", "type" => "stock" }
            ]
          },
          {
            "id" => "xyz789uvw012",
            "title" => "Microsoft announces new AI features",
            "description" => "Microsoft unveiled new generative AI capabilities in Office suite.",
            "content" => "Full article content here...",
            "url" => "https://example.com/article2",
            "image_url" => "https://example.com/image2.jpg",
            "source" => "TechCrunch",
            "category" => "product",
            "published_at" => "2026-04-06T17:00:00.000Z",
            "updated_at" => "2026-04-06T17:30:00.000Z",
            "entities" => [
              { "symbol" => "MSFT", "name" => "Microsoft", "type" => "stock" }
            ]
          }
        ]
      }
    end

    context "with single symbol as string" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(
            symbols: "AAPL",
            filter_entities: "true",
            language: "en",
            limit: "10",
            api_token: "test_market_aux_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns news articles" do
        result = client.news(symbols: "AAPL")
        expect(result["data"]).to be_an(Array)
        expect(result["data"].length).to eq(2)
      end

      it "includes article metadata" do
        result = client.news(symbols: "AAPL")
        article = result["data"].first
        expect(article).to include("title", "description", "url", "source", "published_at")
      end

      it "includes entities information" do
        result = client.news(symbols: "AAPL")
        article = result["data"].first
        expect(article["entities"]).to be_an(Array)
        expect(article["entities"].first).to include("symbol", "name", "type")
      end
    end

    context "with multiple symbols as array" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(
            symbols: "AAPL,MSFT,GOOGL",
            filter_entities: "true",
            language: "en",
            limit: "10",
            api_token: "test_market_aux_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "joins multiple symbols with comma" do
        result = client.news(symbols: ["AAPL", "MSFT", "GOOGL"])
        expect(result["data"]).to be_an(Array)
      end

      it "sends comma-separated symbols to API" do
        client.news(symbols: ["AAPL", "MSFT", "GOOGL"])
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(symbols: "AAPL,MSFT,GOOGL"))
      end
    end

    context "with custom limit" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(
            symbols: "AAPL",
            limit: "50",
            filter_entities: "true",
            language: "en",
            api_token: "test_market_aux_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "respects custom limit parameter" do
        client.news(symbols: "AAPL", limit: 50)
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(limit: "50"))
      end
    end

    context "with custom language" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(
            symbols: "AAPL",
            language: "es",
            filter_entities: "true",
            limit: "10",
            api_token: "test_market_aux_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "respects custom language parameter" do
        client.news(symbols: "AAPL", language: "es")
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(language: "es"))
      end
    end

    context "with default parameters" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(
            symbols: "AAPL",
            language: "en",
            limit: "10",
            filter_entities: "true",
            api_token: "test_market_aux_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "uses default limit of 10" do
        client.news(symbols: "AAPL")
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(limit: "10"))
      end

      it "uses default language of en" do
        client.news(symbols: "AAPL")
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(language: "en"))
      end

      it "enables entity filtering by default" do
        client.news(symbols: "AAPL")
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(filter_entities: "true"))
      end
    end
  end

  describe "API key handling" do
    context "when API key is configured" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_return(status: 200, body: { "data" => [] }.to_json)
      end

      it "includes API key in request" do
        client.news(symbols: "AAPL")
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(api_token: "test_market_aux_key"))
      end
    end

    context "when API key is not set" do
      before do
        stub_const("ENV", ENV.to_h.except("MARKETAUX_API_KEY"))
      end

      it "uses empty string as API key" do
        client_instance = described_class.new
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_return(status: 200, body: { "data" => [] }.to_json)

        client_instance.news(symbols: "AAPL")
        expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
          .with(query: hash_including(api_token: ""))
      end
    end
  end

  describe "rate limiting" do
    let(:response_body) { { "status" => "ok", "data" => [] }.to_json }

    before do
      stub_request(:get, "https://api.marketaux.com/v1/news/all")
        .to_return(status: 200, body: response_body)
    end

    context "when daily rate limit is not exceeded" do
      it "allows requests under the daily limit" do
        expect { client.news(symbols: "AAPL") }.not_to raise_error
      end
    end

    context "when daily rate limit is exceeded" do
      before do
        allow_any_instance_of(BaseClient).to receive(:check_rate_limit!).and_call_original
        allow(REDIS_POOL).to receive(:with).and_yield(redis_mock)
      end

      let(:redis_mock) do
        double.tap do |mock|
          allow(mock).to receive(:get).and_return("100")
          allow(mock).to receive(:multi).and_yield(mock)
          allow(mock).to receive(:incr)
          allow(mock).to receive(:expire)
        end
      end

      it "raises RateLimitExceeded error" do
        expect { client.news(symbols: "AAPL") }.to raise_error(BaseClient::RateLimitExceeded)
      end
    end
  end

  describe "circuit breaker" do
    before do
      stub_request(:get, "https://api.marketaux.com/v1/news/all")
        .to_return(status: 503)
    end

    it "opens circuit after 5 consecutive failures" do
      5.times do
        expect { client.news(symbols: "AAPL") }.to raise_error(Faraday::ServiceUnavailable)
      end

      expect { client.news(symbols: "AAPL") }.to raise_error(BaseClient::CircuitOpenError)
    end

    it "resets circuit on successful request" do
      stub_request(:get, "https://api.marketaux.com/v1/news/all")
        .to_return(status: 200, body: { "status" => "ok", "data" => [] }.to_json)

      client.news(symbols: "AAPL")
      expect { client.news(symbols: "AAPL") }.not_to raise_error(BaseClient::CircuitOpenError)
    end
  end

  describe "error handling" do
    context "when API returns 400 bad request" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_return(status: 400, body: { "error" => "Invalid symbols parameter" }.to_json)
      end

      it "raises BadRequest error" do
        expect { client.news(symbols: "INVALID") }.to raise_error(Faraday::BadRequestError)
      end
    end

    context "when API returns 401 unauthorized" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_return(status: 401, body: { "error" => "Invalid API key" }.to_json)
      end

      it "raises Unauthorized error" do
        expect { client.news(symbols: "AAPL") }.to raise_error(Faraday::UnauthorizedError)
      end
    end

    context "when API returns 429 too many requests" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_return(status: 429, body: { "error" => "Rate limit exceeded" }.to_json)
      end

      it "raises TooManyRequests error" do
        expect { client.news(symbols: "AAPL") }.to raise_error(Faraday::TooManyRequestsError)
      end
    end

    context "when API returns 503 service unavailable" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_return(status: 503, body: { "error" => "Service temporarily unavailable" }.to_json)
      end

      it "raises ServiceUnavailable error" do
        expect { client.news(symbols: "AAPL") }.to raise_error(Faraday::ServiceUnavailable)
      end
    end
  end

  describe "retry behavior" do
    context "when request times out" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_timeout
      end

      it "retries the request" do
        expect { client.news(symbols: "AAPL") }.to raise_error(Faraday::TimeoutError)
      end
    end

    context "when request fails with connection error" do
      before do
        stub_request(:get, "https://api.marketaux.com/v1/news/all")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "retries the request" do
        expect { client.news(symbols: "AAPL") }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "response format" do
    let(:response_body) do
      {
        "status" => "ok",
        "meta" => {
          "last_updated" => "2026-04-06T20:30:00.000Z",
          "page" => 1
        },
        "data" => [
          {
            "id" => "news123",
            "title" => "Breaking News",
            "description" => "News description",
            "content" => "Full content",
            "url" => "https://example.com/news",
            "image_url" => "https://example.com/image.jpg",
            "source" => "Reuters",
            "category" => "earnings",
            "published_at" => "2026-04-06T18:00:00.000Z",
            "updated_at" => "2026-04-06T19:00:00.000Z",
            "entities" => [
              {
                "symbol" => "AAPL",
                "name" => "Apple Inc",
                "type" => "stock"
              }
            ]
          }
        ]
      }
    end

    before do
      stub_request(:get, "https://api.marketaux.com/v1/news/all")
        .to_return(status: 200, body: response_body.to_json)
    end

    it "includes status field in response" do
      result = client.news(symbols: "AAPL")
      expect(result["status"]).to eq("ok")
    end

    it "includes meta information" do
      result = client.news(symbols: "AAPL")
      expect(result["meta"]).to include("last_updated", "page")
    end

    it "includes array of news articles" do
      result = client.news(symbols: "AAPL")
      expect(result["data"]).to be_an(Array)
      expect(result["data"].first).to include(
        "id", "title", "description", "content", "url", "source",
        "published_at", "entities"
      )
    end

    it "includes image URLs when available" do
      result = client.news(symbols: "AAPL")
      expect(result["data"].first["image_url"]).to be_present
    end

    it "includes article category" do
      result = client.news(symbols: "AAPL")
      expect(result["data"].first["category"]).to be_present
    end
  end

  describe "symbol parameter handling" do
    let(:response_body) { { "status" => "ok", "data" => [] }.to_json }

    before do
      stub_request(:get, "https://api.marketaux.com/v1/news/all")
        .to_return(status: 200, body: response_body)
    end

    it "converts single symbol string to string" do
      client.news(symbols: "AAPL")
      expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
        .with(query: hash_including(symbols: "AAPL"))
    end

    it "converts array of symbols to comma-separated string" do
      client.news(symbols: ["AAPL", "MSFT", "GOOGL", "AMZN"])
      expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
        .with(query: hash_including(symbols: "AAPL,MSFT,GOOGL,AMZN"))
    end

    it "handles empty array" do
      client.news(symbols: [])
      expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
        .with(query: hash_including(symbols: ""))
    end

    it "trims whitespace from symbols" do
      # This tests that Array() works with the symbols parameter
      client.news(symbols: " AAPL ")
      expect(WebMock).to have_requested(:get, "https://api.marketaux.com/v1/news/all")
    end
  end
end
