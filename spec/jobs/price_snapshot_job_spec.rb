# frozen_string_literal: true

require "rails_helper"

RSpec.describe PriceSnapshotJob do
  let(:quote_data) { { "c" => 155.0, "o" => 150.0, "h" => 156.0, "l" => 149.0, "v" => 80_000_000, "dp" => 3.33, "d" => 5.0, "pc" => 150.0 } }

  before do
    stub_request(:get, /finnhub.io/).to_return(
      status: 200,
      body: quote_data.to_json,
      headers: { "Content-Type" => "application/json" }
    )
    allow(PricesChannel).to receive(:broadcast_price)
  end

  it "creates a price snapshot" do
    expect { described_class.new.perform("AAPL") }.to change(PriceSnapshot, :count).by(1)

    snapshot = PriceSnapshot.last
    expect(snapshot.symbol).to eq("AAPL")
    expect(snapshot.price).to eq(155.0)
  end

  it "broadcasts price update via ActionCable" do
    described_class.new.perform("AAPL")
    expect(PricesChannel).to have_received(:broadcast_price).with("AAPL", quote_data)
  end

  it "triggers matching alerts" do
    user = create(:user)
    create(:alert, user: user, symbol: "AAPL", alert_type: "price_above", condition: { "value" => 150.0 })

    expect { described_class.new.perform("AAPL") }.to change(AlertHistory, :count).by(1)
  end
end
