# frozen_string_literal: true

require "rails_helper"

RSpec.describe WatchlistItem, type: :model do
  describe "validations" do
    subject { build(:watchlist_item) }

    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:company_name) }
    it { should validate_length_of(:symbol).is_at_most(10) }
    it { should validate_numericality_of(:priority).only_integer }

    it "validates symbol format" do
      expect(build(:watchlist_item, symbol: "aapl")).to be_valid # upcased by callback
      expect(build(:watchlist_item, symbol: "INVALID SYMBOL")).not_to be_valid
    end

    it "validates uniqueness scoped to user" do
      item = create(:watchlist_item)
      dup = build(:watchlist_item, user: item.user, symbol: item.symbol)
      expect(dup).not_to be_valid
    end
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let!(:active) { create(:watchlist_item, user: user) }
    let!(:inactive) { create(:watchlist_item, :inactive, user: user, symbol: "TSLA", company_name: "Tesla") }

    it ".active returns only active items" do
      expect(WatchlistItem.active).to include(active)
      expect(WatchlistItem.active).not_to include(inactive)
    end

    it ".by_priority orders by priority descending" do
      high = create(:watchlist_item, :high_priority, user: user, symbol: "GOOGL", company_name: "Google")
      expect(WatchlistItem.by_priority.first).to eq(high)
    end
  end

  describe ".all_active_symbols" do
    it "returns distinct symbols from active items" do
      user = create(:user)
      create(:watchlist_item, user: user, symbol: "AAPL")
      create(:watchlist_item, user: user, symbol: "TSLA", company_name: "Tesla")
      create(:watchlist_item, :inactive, user: user, symbol: "MSFT", company_name: "Microsoft")

      symbols = WatchlistItem.all_active_symbols
      expect(symbols).to include("AAPL", "TSLA")
      expect(symbols).not_to include("MSFT")
    end
  end

  describe "#soft_delete!" do
    it "sets is_active to false" do
      item = create(:watchlist_item)
      item.soft_delete!
      expect(item.reload.is_active).to be false
    end
  end

  describe "before_validation callback" do
    it "upcases symbol" do
      item = build(:watchlist_item, symbol: "aapl")
      item.valid?
      expect(item.symbol).to eq("AAPL")
    end
  end
end
