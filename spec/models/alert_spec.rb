# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alert do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:alert_histories).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:symbol) }
    it { is_expected.to validate_presence_of(:alert_type) }
    it { is_expected.to validate_numericality_of(:cooldown_minutes).is_greater_than_or_equal_to(1) }

    it "validates alert_type inclusion" do
      alert = build(:alert, alert_type: "invalid")
      expect(alert).not_to be_valid
    end
  end

  describe "callbacks" do
    it "upcases symbol before validation" do
      alert = build(:alert, symbol: "aapl")
      alert.valid?
      expect(alert.symbol).to eq("AAPL")
    end
  end

  describe "scopes" do
    it "returns active alerts" do
      active = create(:alert, active: true)
      create(:alert, active: false)
      expect(Alert.active).to eq([active])
    end
  end

  describe "#cooldown_active?" do
    it "returns false when never triggered" do
      alert = build(:alert, last_triggered_at: nil)
      expect(alert.cooldown_active?).to be false
    end

    it "returns true when recently triggered" do
      alert = build(:alert, last_triggered_at: 5.minutes.ago, cooldown_minutes: 15)
      expect(alert.cooldown_active?).to be true
    end

    it "returns false when cooldown expired" do
      alert = build(:alert, last_triggered_at: 20.minutes.ago, cooldown_minutes: 15)
      expect(alert.cooldown_active?).to be false
    end
  end

  describe "#record_trigger!" do
    it "updates last_triggered_at and increments count" do
      alert = create(:alert, trigger_count: 0)
      alert.record_trigger!
      alert.reload
      expect(alert.trigger_count).to eq(1)
      expect(alert.last_triggered_at).to be_within(1.second).of(Time.current)
    end
  end
end
