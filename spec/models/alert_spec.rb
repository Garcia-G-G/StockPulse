# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alert, type: :model do
  describe "validations" do
    subject { build(:alert) }

    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:alert_type) }
    it { should validate_numericality_of(:cooldown_minutes).only_integer }
    it { should validate_numericality_of(:trigger_count).only_integer }

    it "validates alert_type inclusion" do
      alert = build(:alert, alert_type: "invalid_type")
      expect(alert).not_to be_valid
    end

    context "condition validation" do
      it "requires target_price for price_above" do
        alert = build(:alert, alert_type: "price_above", condition: { target_price: -1 })
        expect(alert).not_to be_valid
        expect(alert.errors[:condition]).to be_present
      end

      it "accepts valid price_above condition" do
        alert = build(:alert, alert_type: "price_above", condition: { target_price: 200.0 })
        expect(alert).to be_valid
      end

      it "requires threshold_percent and timeframe for percent_change_up" do
        alert = build(:alert, :percent_change_up, condition: { threshold_percent: -1 })
        expect(alert).not_to be_valid
      end

      it "requires lower < upper for price_range_break" do
        alert = build(:alert, :price_range_break, condition: { lower: 200, upper: 100 })
        expect(alert).not_to be_valid
      end

      it "requires threshold 0-100 for rsi_overbought" do
        alert = build(:alert, :rsi_overbought, condition: { threshold: 150 })
        expect(alert).not_to be_valid
      end

      it "requires min_sentiment_score 0-1 for news_high_impact" do
        alert = build(:alert, :news_impact, condition: { min_sentiment_score: 1.5 })
        expect(alert).not_to be_valid
      end
    end
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:alert_histories).dependent(:destroy) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:enabled) { create(:alert, user: user) }
    let!(:disabled) { create(:alert, user: user, is_enabled: false) }

    it ".enabled returns only enabled alerts" do
      expect(Alert.enabled).to include(enabled)
      expect(Alert.enabled).not_to include(disabled)
    end

    it ".for_symbol filters by symbol" do
      other = create(:alert, user: user, symbol: "TSLA", condition: { target_price: 300.0 })
      expect(Alert.for_symbol("AAPL")).to include(enabled)
      expect(Alert.for_symbol("AAPL")).not_to include(other)
    end

    it ".price_alerts returns price type alerts" do
      expect(Alert.price_alerts).to include(enabled)
    end
  end

  describe "#in_cooldown?" do
    it "returns false when never triggered" do
      alert = build(:alert, last_triggered_at: nil)
      expect(alert.in_cooldown?).to be false
    end

    it "returns true when triggered within cooldown" do
      alert = build(:alert, :in_cooldown)
      expect(alert.in_cooldown?).to be true
    end

    it "returns false when cooldown has expired" do
      alert = build(:alert, :triggered)
      expect(alert.in_cooldown?).to be false
    end
  end

  describe "#record_trigger!" do
    let(:alert) { create(:alert) }

    it "updates last_triggered_at and increments trigger_count" do
      alert.record_trigger!
      expect(alert.trigger_count).to eq(1)
      expect(alert.last_triggered_at).to be_within(1.second).of(Time.current)
    end

    it "auto-disables one-time alerts" do
      alert = create(:alert, :one_time)
      alert.record_trigger!
      expect(alert.is_enabled).to be false
    end

    it "auto-disables when max_triggers reached" do
      alert = create(:alert, max_triggers: 2, trigger_count: 1)
      alert.record_trigger!
      expect(alert.is_enabled).to be false
    end
  end

  describe "#price_type? and #technical_type?" do
    it "identifies price types" do
      expect(build(:alert).price_type?).to be true
      expect(build(:alert, :rsi_overbought).price_type?).to be false
    end

    it "identifies technical types" do
      expect(build(:alert, :rsi_overbought).technical_type?).to be true
      expect(build(:alert).technical_type?).to be false
    end
  end
end
