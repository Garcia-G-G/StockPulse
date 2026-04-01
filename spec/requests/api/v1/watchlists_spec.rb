# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Watchlists", type: :request do
  let!(:user) { create(:user) }
  let(:headers) { { "X-Telegram-Chat-Id" => user.telegram_chat_id } }

  describe "authentication" do
    it "returns 401 without auth header" do
      get "/api/v1/watchlists"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid chat id" do
      get "/api/v1/watchlists", headers: { "X-Telegram-Chat-Id" => "nonexistent" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/watchlists" do
    it "returns user watchlist items" do
      create(:watchlist_item, user: user)
      get "/api/v1/watchlists", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(1)
    end
  end

  describe "POST /api/v1/watchlists" do
    it "creates a watchlist item" do
      params = { watchlist_item: { symbol: "TSLA", company_name: "Tesla", exchange: "NASDAQ" } }
      expect {
        post "/api/v1/watchlists", params: params, headers: headers
      }.to change(WatchlistItem, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "rejects invalid symbol" do
      params = { watchlist_item: { symbol: "", company_name: "Test" } }
      post "/api/v1/watchlists", params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/watchlists/:id" do
    it "deletes a watchlist item" do
      item = create(:watchlist_item, user: user)
      expect {
        delete "/api/v1/watchlists/#{item.id}", headers: headers
      }.to change(WatchlistItem, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
