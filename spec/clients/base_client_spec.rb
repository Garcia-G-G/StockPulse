# frozen_string_literal: true

require "rails_helper"

RSpec.describe BaseClient, type: :client do
  describe "instantiation" do
    it "raises NotImplementedError when instantiated directly" do
      expect { BaseClient.new(api_name: "test", base_url: "http://test.com", rate_limit: 10) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "rate limiting" do
    let(:client) { FinnhubClient.new }

    it "allows requests under limit" do
      expect(client.remaining_calls).to eq(60)
    end

    it "tracks remaining calls after use" do
      REDIS_POOL.with { |r| r.set("ratelimit:finnhub", "5") }
      expect(client.remaining_calls).to eq(55)
    end
  end

  describe "circuit breaker" do
    let(:client) { FinnhubClient.new }

    it "opens after 5 consecutive failures" do
      5.times do
        REDIS_POOL.with { |r| r.incr("circuit:finnhub:failures") }
      end
      REDIS_POOL.with do |r|
        r.set("circuit:finnhub", "open")
        r.set("circuit:finnhub:opened_at", Time.current.to_f.to_s)
      end

      expect { client.send(:check_circuit!) }.to raise_error(BaseClient::CircuitOpen)
    end
  end

  describe "caching" do
    let(:client) { FinnhubClient.new }

    it "returns cached response on second call" do
      stub_request(:get, /finnhub\.io.*quote/)
        .to_return(body: { c: 195.5 }.to_json, headers: { "Content-Type" => "application/json" })

      first = client.quote("AAPL")
      second = client.quote("AAPL")
      expect(second).to eq(first)
    end
  end
end
