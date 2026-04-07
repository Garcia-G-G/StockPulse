# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "associations" do
    it { is_expected.to have_many(:watchlist_items).dependent(:destroy) }
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
    it { is_expected.to have_many(:alert_histories).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_uniqueness_of(:telegram_chat_id).allow_blank }
    it { is_expected.to validate_uniqueness_of(:email).allow_blank }
  end

  describe "scopes" do
    it "returns active users" do
      active = create(:user, active: true)
      create(:user, :inactive)

      expect(User.active).to eq([active])
    end
  end

  describe "#notification_channels" do
    it "returns telegram when chat_id present" do
      user = build(:user, telegram_chat_id: "123", email: nil, whatsapp_number: nil)
      expect(user.notification_channels).to eq([:telegram])
    end

    it "returns all channels when all present" do
      user = build(:user, telegram_chat_id: "123", email: "a@b.com", whatsapp_number: "+1234")
      expect(user.notification_channels).to eq(%i[telegram email whatsapp])
    end

    it "returns empty when no channels configured" do
      user = build(:user, telegram_chat_id: nil, email: nil, whatsapp_number: nil)
      expect(user.notification_channels).to be_empty
    end
  end

  describe "#can_receive_notifications?" do
    it "returns true for active unmuted user" do
      user = build(:user, active: true, notifications_muted: false)
      expect(user.can_receive_notifications?).to be true
    end

    it "returns false for muted user" do
      user = build(:user, :muted)
      expect(user.can_receive_notifications?).to be false
    end

    it "returns false for inactive user" do
      user = build(:user, :inactive)
      expect(user.can_receive_notifications?).to be false
    end
  end
end
