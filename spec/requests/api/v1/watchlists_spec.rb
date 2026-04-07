# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Watchlists" do
  let(:user) { create(:user) }
  let(:auth_headers) { { "X-Telegram-Chat-Id" => user.telegram_chat_id } }

  describe "GET /api/v1/watchlists" do
    it "returns the user's active watchlist items" do
      create(:watchlist_item, user: user, symbol: "AAPL")
      create(:watchlist_item, user: user, symbol: "MSFT")
      create(:watchlist_item, user: user, symbol: "GOOG", active: false)

      get "/api/v1/watchlists", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data.size).to eq(2)
    end

    it "returns 401 without auth" do
      get "/api/v1/watchlists"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/watchlists" do
    it "creates a watchlist item" do
      post "/api/v1/watchlists", params: { watchlist_item: { symbol: "AAPL", name: "Apple", exchange: "NASDAQ" } }, headers: auth_headers

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)["data"]
      expect(data["attributes"]["symbol"]).to eq("AAPL")
    end

    it "rejects invalid symbols" do
      post "/api/v1/watchlists", params: { watchlist_item: { symbol: "INVALID SYMBOL!!" } }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/watchlists/:id" do
    it "destroys the watchlist item" do
      item = create(:watchlist_item, user: user)

      expect { delete "/api/v1/watchlists/#{item.id}", headers: auth_headers }.to change(WatchlistItem, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/watchlists/:id/quote" do
    it "returns quote data from Finnhub" do
      item = create(:watchlist_item, user: user, symbol: "AAPL")
      stub_request(:get, /finnhub.io/).to_return(
        status: 200,
        body: { c: 150.0, d: 2.0, dp: 1.35, h: 152.0, l: 148.0, o: 149.0, pc: 148.0, t: Time.current.to_i }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      get "/api/v1/watchlists/#{item.id}/quote", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end
end
