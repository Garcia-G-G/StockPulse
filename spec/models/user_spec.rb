# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:username) }
    it { should validate_uniqueness_of(:username) }
    it { should validate_length_of(:username).is_at_most(50) }
    it { should allow_value("test@example.com").for(:email) }
    it { should_not allow_value("invalid").for(:email) }
    it { should allow_value(nil).for(:email) }
    it { should allow_value("+12345678901").for(:whatsapp_number) }
    it { should_not allow_value("12345").for(:whatsapp_number) }
    it { should validate_presence_of(:timezone) }

    it "requires at least one notification channel" do
      user = build(:user, telegram_chat_id: nil, email: nil, whatsapp_number: nil)
      expect(user).not_to be_valid
      expect(user.errors[:base]).to include("at least one notification channel (telegram, email, or whatsapp) must be present")
    end
  end

  describe "associations" do
    it { should have_many(:watchlist_items).dependent(:destroy) }
    it { should have_many(:alerts).dependent(:destroy) }
    it { should have_many(:alert_histories).dependent(:destroy) }
  end

  describe "scopes" do
    let!(:active_user) { create(:user) }
    let!(:inactive_user) { create(:user, is_active: false) }
    let!(:muted_user) { create(:user, :muted) }

    it ".active returns only active users" do
      expect(User.active).to include(active_user)
      expect(User.active).not_to include(inactive_user)
    end

    it ".not_muted excludes currently muted users" do
      expect(User.not_muted).to include(active_user)
      expect(User.not_muted).not_to include(muted_user)
    end

    it ".with_telegram returns users with telegram_chat_id" do
      no_tg = create(:user, :no_telegram, email: "test@test.com")
      expect(User.with_telegram).to include(active_user)
      expect(User.with_telegram).not_to include(no_tg)
    end
  end

  describe "#muted?" do
    it "returns true when muted_until is in the future" do
      user = build(:user, :muted)
      expect(user.muted?).to be true
    end

    it "returns false when muted_until is in the past" do
      user = build(:user, muted_until: 1.hour.ago)
      expect(user.muted?).to be false
    end

    it "returns false when muted_until is nil" do
      user = build(:user, muted_until: nil)
      expect(user.muted?).to be false
    end
  end

  describe "#mute! and #unmute!" do
    let(:user) { create(:user) }

    it "mutes for specified minutes" do
      user.mute!(30)
      expect(user.muted?).to be true
      expect(user.muted_until).to be_within(1.second).of(30.minutes.from_now)
    end

    it "unmutes immediately" do
      user.mute!(60)
      user.unmute!
      expect(user.muted?).to be false
    end
  end

  describe "#enabled_channels" do
    it "returns telegram when enabled and chat_id present" do
      user = build(:user)
      expect(user.enabled_channels).to include(:telegram)
    end

    it "returns email when enabled and email present" do
      user = build(:user)
      expect(user.enabled_channels).to include(:email)
    end

    it "excludes channels without credentials" do
      user = build(:user, :no_telegram)
      expect(user.enabled_channels).not_to include(:telegram)
    end
  end

  describe "#in_quiet_hours?" do
    it "returns false during business hours" do
      user = build(:user, notification_preferences: {
        telegram: { enabled: true, quiet_start: "23:00", quiet_end: "07:00" },
        email: { enabled: true }
      })
      # Simulate 2 PM ET — outside quiet hours
      allow(Time).to receive(:current).and_return(
        Time.find_zone("Eastern Time (US & Canada)").parse("2026-03-31 14:00")
      )
      expect(user.in_quiet_hours?).to be false
    end
  end
end
