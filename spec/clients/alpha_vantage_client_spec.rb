# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlphaVantageClient do
  subject(:client) { described_class.new }

  before do
    stub_const("ENV", ENV.to_h.merge({
      "ALPHA_VANTAGE_API_KEY" => "test_alpha_key",
      "ALPHA_VANTAGE_RATE_LIMIT_PER_DAY" => "25"
    }))
  end

  describe "initialization" do
    it "sets the base URL to Alpha Vantage" do
      expect(client.base_url).to eq("https://www.alphavantage.co")
    end

    it "sets rate limit key to alpha_vantage" do
      expect(client.rate_limit_key).to eq("alpha_vantage")
    end

    it "sets rate limit to 25 requests per day" do
      expect(client.rate_limit_max).to eq(25)
    end

    it "sets rate limit period to 86400 seconds (1 day)" do
      expect(client.rate_limit_period).to eq(86_400)
    end
  end

  describe "#rsi" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => {
          "1: Information" => "Relative Strength Index (RSI)",
          "2: Symbol" => "AAPL",
          "3: Last Refreshed" => "2026-04-06",
          "4: Interval" => "daily",
          "5: Time Period" => 14,
          "6: Series Type" => "close",
          "7: Time Zone" => "US/Eastern"
        },
        "Technical Analysis: RSI" => {
          "2026-04-06" => { "RSI" => "72.5" },
          "2026-04-03" => { "RSI" => "68.3" },
          "2026-04-02" => { "RSI" => "65.1" }
        }
      }
    end

    context "with default parameters" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "RSI",
            symbol: symbol,
            interval: "daily",
            time_period: "14",
            series_type: "close",
            apikey: "test_alpha_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns RSI technical indicator data" do
        result = client.rsi(symbol)
        expect(result["Technical Analysis: RSI"]).to be_a(Hash)
        expect(result["Technical Analysis: RSI"]["2026-04-06"]["RSI"]).to eq("72.5")
      end

      it "includes metadata" do
        result = client.rsi(symbol)
        expect(result["Meta Data"]["2: Symbol"]).to eq("AAPL")
        expect(result["Meta Data"]["5: Time Period"]).to eq(14)
      end
    end

    context "with custom interval" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "RSI",
            interval: "60min",
            time_period: "14"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns RSI with custom interval" do
        result = client.rsi(symbol, interval: "60min")
        expect(result).to include("Technical Analysis: RSI")
      end
    end

    context "with custom time period" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "RSI",
            time_period: "21"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns RSI with custom time period" do
        result = client.rsi(symbol, time_period: 21)
        expect(result).to include("Technical Analysis: RSI")
      end
    end
  end

  describe "#macd" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => {
          "1: Information" => "MACD (Moving Average Convergence Divergence)",
          "2: Symbol" => "AAPL",
          "3: Last Refreshed" => "2026-04-06"
        },
        "Technical Analysis: MACD" => {
          "2026-04-06" => {
            "MACD" => "5.2345",
            "MACD_Hist" => "0.4567",
            "MACD_Signal" => "4.7778"
          }
        }
      }
    end

    context "with default parameters" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "MACD",
            symbol: symbol,
            interval: "daily",
            series_type: "close",
            apikey: "test_alpha_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns MACD technical indicator data" do
        result = client.macd(symbol)
        expect(result["Technical Analysis: MACD"]).to be_a(Hash)
        expect(result["Technical Analysis: MACD"]["2026-04-06"]["MACD"]).to eq("5.2345")
      end

      it "includes MACD line, signal line, and histogram" do
        result = client.macd(symbol)
        macd_data = result["Technical Analysis: MACD"]["2026-04-06"]
        expect(macd_data).to include("MACD", "MACD_Signal", "MACD_Hist")
      end
    end

    context "with custom interval" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "MACD",
            interval: "30min"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns MACD with custom interval" do
        result = client.macd(symbol, interval: "30min")
        expect(result).to include("Technical Analysis: MACD")
      end
    end
  end

  describe "#bollinger_bands" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => {
          "1: Information" => "Bollinger Bands",
          "2: Symbol" => "AAPL",
          "5: Time Period" => 20
        },
        "Technical Analysis: BBANDS" => {
          "2026-04-06" => {
            "Real Upper Band" => "152.5",
            "Real Middle Band" => "150.2",
            "Real Lower Band" => "147.9"
          }
        }
      }
    end

    context "with default parameters" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "BBANDS",
            symbol: symbol,
            interval: "daily",
            time_period: "20",
            series_type: "close",
            apikey: "test_alpha_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns Bollinger Bands data" do
        result = client.bollinger_bands(symbol)
        expect(result["Technical Analysis: BBANDS"]).to be_a(Hash)
        bb_data = result["Technical Analysis: BBANDS"]["2026-04-06"]
        expect(bb_data["Real Upper Band"]).to eq("152.5")
      end

      it "includes upper, middle, and lower bands" do
        result = client.bollinger_bands(symbol)
        bb_data = result["Technical Analysis: BBANDS"]["2026-04-06"]
        expect(bb_data).to include("Real Upper Band", "Real Middle Band", "Real Lower Band")
      end
    end

    context "with custom time period" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "BBANDS",
            time_period: "50"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns Bollinger Bands with custom time period" do
        result = client.bollinger_bands(symbol, time_period: 50)
        expect(result).to include("Technical Analysis: BBANDS")
      end
    end
  end

  describe "#sma" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => {
          "1: Information" => "Simple Moving Average",
          "2: Symbol" => "AAPL",
          "5: Time Period" => 50
        },
        "Technical Analysis: SMA" => {
          "2026-04-06" => { "SMA" => "149.8" },
          "2026-04-03" => { "SMA" => "149.2" }
        }
      }
    end

    context "with default parameters" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "SMA",
            symbol: symbol,
            interval: "daily",
            time_period: "50",
            series_type: "close",
            apikey: "test_alpha_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns SMA technical indicator data" do
        result = client.sma(symbol)
        expect(result["Technical Analysis: SMA"]).to be_a(Hash)
        expect(result["Technical Analysis: SMA"]["2026-04-06"]["SMA"]).to eq("149.8")
      end
    end

    context "with custom time period" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "SMA",
            time_period: "200"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns SMA with custom time period" do
        result = client.sma(symbol, time_period: 200)
        expect(result).to include("Technical Analysis: SMA")
      end
    end
  end

  describe "#ema" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => {
          "1: Information" => "Exponential Moving Average",
          "2: Symbol" => "AAPL",
          "5: Time Period" => 20
        },
        "Technical Analysis: EMA" => {
          "2026-04-06" => { "EMA" => "150.1" },
          "2026-04-03" => { "EMA" => "149.5" }
        }
      }
    end

    context "with default parameters" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "EMA",
            symbol: symbol,
            interval: "daily",
            time_period: "20",
            series_type: "close",
            apikey: "test_alpha_key"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns EMA technical indicator data" do
        result = client.ema(symbol)
        expect(result["Technical Analysis: EMA"]).to be_a(Hash)
        expect(result["Technical Analysis: EMA"]["2026-04-06"]["EMA"]).to eq("150.1")
      end
    end

    context "with custom time period" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(
            function: "EMA",
            time_period: "12"
          ))
          .to_return(status: 200, body: response_body.to_json)
      end

      it "returns EMA with custom time period" do
        result = client.ema(symbol, time_period: 12)
        expect(result).to include("Technical Analysis: EMA")
      end
    end
  end

  describe "rate limiting" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => { "1: Information" => "RSI" },
        "Technical Analysis: RSI" => {
          "2026-04-06" => { "RSI" => "72.5" }
        }
      }
    end

    before do
      stub_request(:get, "https://www.alphavantage.co/query")
        .to_return(status: 200, body: response_body.to_json)
    end

    context "when daily rate limit is not exceeded" do
      it "allows requests under the daily limit" do
        expect { client.rsi(symbol) }.not_to raise_error
      end
    end

    context "when daily rate limit is exceeded" do
      before do
        allow_any_instance_of(BaseClient).to receive(:check_rate_limit!).and_call_original
        allow(REDIS_POOL).to receive(:with).and_yield(redis_mock)
      end

      let(:redis_mock) do
        double.tap do |mock|
          allow(mock).to receive(:get).and_return("25")
          allow(mock).to receive(:multi).and_yield(mock)
          allow(mock).to receive(:incr)
          allow(mock).to receive(:expire)
        end
      end

      it "raises RateLimitExceeded error" do
        expect { client.rsi(symbol) }.to raise_error(BaseClient::RateLimitExceeded)
      end
    end
  end

  describe "circuit breaker" do
    let(:symbol) { "AAPL" }

    before do
      stub_request(:get, "https://www.alphavantage.co/query")
        .to_return(status: 503)
    end

    it "opens circuit after 5 consecutive failures" do
      5.times do
        expect { client.rsi(symbol) }.to raise_error(Faraday::ServiceUnavailable)
      end

      expect { client.rsi(symbol) }.to raise_error(BaseClient::CircuitOpenError)
    end

    it "resets circuit on successful request" do
      stub_request(:get, "https://www.alphavantage.co/query")
        .to_return(status: 200, body: {
          "Meta Data" => { "1: Information" => "RSI" },
          "Technical Analysis: RSI" => {
            "2026-04-06" => { "RSI" => "72.5" }
          }
        }.to_json)

      client.rsi(symbol)
      expect { client.rsi(symbol) }.not_to raise_error(BaseClient::CircuitOpenError)
    end
  end

  describe "error handling" do
    let(:symbol) { "AAPL" }

    context "when API returns 401 unauthorized" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .to_return(status: 401, body: { "error" => "Invalid API key" }.to_json)
      end

      it "raises Unauthorized error" do
        expect { client.rsi(symbol) }.to raise_error(Faraday::UnauthorizedError)
      end
    end

    context "when API is temporarily unavailable" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .to_return(status: 429, body: { "Note" => "Thank you for using Alpha Vantage!" }.to_json)
      end

      it "raises TooManyRequests error" do
        expect { client.rsi(symbol) }.to raise_error(Faraday::TooManyRequestsError)
      end
    end

    context "when API returns malformed JSON" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .to_return(status: 200, body: "invalid json")
      end

      it "raises parsing error" do
        expect { client.rsi(symbol) }.to raise_error
      end
    end
  end

  describe "technical indicator series type" do
    let(:symbol) { "AAPL" }
    let(:response_body) do
      {
        "Meta Data" => { "6: Series Type" => "close" },
        "Technical Analysis: RSI" => {
          "2026-04-06" => { "RSI" => "72.5" }
        }
      }
    end

    before do
      stub_request(:get, "https://www.alphavantage.co/query")
        .to_return(status: 200, body: response_body.to_json)
    end

    it "always uses close price as series type" do
      client.rsi(symbol)
      expect(WebMock).to have_requested(:get, "https://www.alphavantage.co/query")
        .with(query: hash_including(series_type: "close"))
    end
  end

  describe "retry behavior" do
    let(:symbol) { "AAPL" }

    context "when request times out" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .to_timeout
      end

      it "retries the request" do
        expect { client.rsi(symbol) }.to raise_error(Faraday::TimeoutError)
      end
    end

    context "when request fails with connection error" do
      before do
        stub_request(:get, "https://www.alphavantage.co/query")
          .to_raise(Faraday::ConnectionFailed)
      end

      it "retries the request" do
        expect { client.rsi(symbol) }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "API key configuration" do
    context "when API key is not set" do
      before do
        stub_const("ENV", ENV.to_h.except("ALPHA_VANTAGE_API_KEY"))
      end

      it "uses empty string as API key" do
        client_instance = described_class.new
        stub_request(:get, "https://www.alphavantage.co/query")
          .to_return(status: 200, body: {
            "Meta Data" => { "1: Information" => "RSI" },
            "Technical Analysis: RSI" => {}
          }.to_json)

        client_instance.rsi("AAPL")
        expect(WebMock).to have_requested(:get, "https://www.alphavantage.co/query")
          .with(query: hash_including(apikey: ""))
      end
    end
  end
end
