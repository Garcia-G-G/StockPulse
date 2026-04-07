# frozen_string_literal: true

require "rails_helper"

RSpec.describe WatchlistItem do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:watchlist_item) }

    it { is_expected.to validate_presence_of(:symbol) }
    it { is_expected.to validate_uniqueness_of(:symbol).scoped_to(:user_id) }

    it "validates symbol format" do
      item = build(:watchlist_item, symbol: "invalid symbol!")
      expect(item).not_to be_valid
    end

    it "accepts valid symbols" do
      item = build(:watchlist_item, symbol: "AAPL")
      expect(item).to be_valid
    end
  end

  describe "callbacks" do
    it "upcases symbol before validation" do
      item = build(:watchlist_item, symbol: "aapl")
      item.valid?
      expect(item.symbol).to eq("AAPL")
    end
  end

  describe "scopes" do
    it "returns active items" do
      active = create(:watchlist_item, active: true)
      create(:watchlist_item, active: false, user: active.user, symbol: "MSFT")
      expect(WatchlistItem.active).to eq([active])
    end
  end
end
