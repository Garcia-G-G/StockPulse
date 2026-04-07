# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Alerts" do
  let(:user) { create(:user) }
  let(:auth_headers) { { "X-Telegram-Chat-Id" => user.telegram_chat_id } }

  describe "GET /api/v1/alerts" do
    it "returns active alerts" do
      create(:alert, user: user, symbol: "AAPL")
      create(:alert, user: user, symbol: "MSFT", active: false)

      get "/api/v1/alerts", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data.size).to eq(1)
    end
  end

  describe "POST /api/v1/alerts" do
    it "creates an alert" do
      post "/api/v1/alerts", params: {
        alert: { symbol: "AAPL", alert_type: "price_above", condition: { value: 200 }, cooldown_minutes: 15 }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)["data"]
      expect(data["attributes"]["symbol"]).to eq("AAPL")
    end

    it "rejects invalid alert type" do
      post "/api/v1/alerts", params: {
        alert: { symbol: "AAPL", alert_type: "invalid_type", condition: { value: 200 } }
      }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/alerts/:id" do
    it "updates an alert" do
      alert = create(:alert, user: user)

      patch "/api/v1/alerts/#{alert.id}", params: { alert: { cooldown_minutes: 30 } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(alert.reload.cooldown_minutes).to eq(30)
    end
  end

  describe "DELETE /api/v1/alerts/:id" do
    it "destroys an alert" do
      alert = create(:alert, user: user)

      expect { delete "/api/v1/alerts/#{alert.id}", headers: auth_headers }.to change(Alert, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/alerts/history" do
    it "returns alert history" do
      alert = create(:alert, user: user)
      create(:alert_history, alert: alert, user: user, symbol: "AAPL")

      get "/api/v1/alerts/history", headers: auth_headers

      expect(response).to have_http_status(:ok)
    end
  end
end
