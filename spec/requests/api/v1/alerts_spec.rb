# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Alerts", type: :request do
  let!(:user) { create(:user) }
  let(:headers) { { "X-Telegram-Chat-Id" => user.telegram_chat_id } }

  describe "GET /api/v1/alerts" do
    it "returns enabled alerts" do
      create(:alert, user: user)
      create(:alert, user: user, is_enabled: false, symbol: "TSLA", condition: { target_price: 300.0 })
      get "/api/v1/alerts", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"].length).to eq(1)
    end
  end

  describe "POST /api/v1/alerts" do
    it "creates an alert with valid params" do
      params = { alert: { symbol: "AAPL", alert_type: "price_above",
                           condition: { target_price: 200.0 }, cooldown_minutes: 15 } }
      expect {
        post "/api/v1/alerts", params: params, headers: headers, as: :json
      }.to change(Alert, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /api/v1/alerts/:id" do
    it "deletes an alert" do
      alert = create(:alert, user: user)
      expect {
        delete "/api/v1/alerts/#{alert.id}", headers: headers
      }.to change(Alert, :count).by(-1)
    end
  end
end
