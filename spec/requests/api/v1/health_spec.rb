# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Health" do
  describe "GET /api/v1/health" do
    it "returns health status" do
      allow(Sidekiq::Stats).to receive(:new).and_return(double(processes_size: 1))

      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body).to have_key("database")
      expect(body).to have_key("redis")
    end
  end

  describe "GET /api/v1/health/metrics" do
    it "returns metrics" do
      allow(Sidekiq::Stats).to receive(:new).and_return(double(queues: {}))

      get "/api/v1/health/metrics"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("watchlist_items")
      expect(body).to have_key("active_alerts")
    end
  end
end
