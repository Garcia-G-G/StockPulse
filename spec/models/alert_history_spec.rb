# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertHistory, type: :model do
  describe "validations" do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:alert_type) }
    it { should validate_presence_of(:triggered_at) }
    it { should validate_presence_of(:price_at_trigger) }
  end

  describe "associations" do
    it { should belong_to(:alert) }
    it { should belong_to(:user) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:alert) { create(:alert, user: user) }

    it ".recent orders by triggered_at desc" do
      old = create(:alert_history, alert: alert, user: user, triggered_at: 1.day.ago)
      recent = create(:alert_history, alert: alert, user: user, triggered_at: 1.hour.ago)
      expect(AlertHistory.recent.first).to eq(recent)
    end

    it ".today returns only today's records" do
      today = create(:alert_history, alert: alert, user: user, triggered_at: Time.current)
      yesterday = create(:alert_history, alert: alert, user: user, triggered_at: 1.day.ago)
      expect(AlertHistory.today).to include(today)
      expect(AlertHistory.today).not_to include(yesterday)
    end
  end

  describe ".daily_stats" do
    it "groups by alert_type and counts" do
      user = create(:user)
      alert = create(:alert, user: user)
      create(:alert_history, alert: alert, user: user, alert_type: "price_above", triggered_at: Time.current)
      create(:alert_history, alert: alert, user: user, alert_type: "price_above", triggered_at: Time.current)
      create(:alert_history, alert: alert, user: user, alert_type: "rsi_overbought", triggered_at: Time.current)

      stats = AlertHistory.daily_stats(user.id)
      expect(stats["price_above"]).to eq(2)
      expect(stats["rsi_overbought"]).to eq(1)
    end
  end
end
