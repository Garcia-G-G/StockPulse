# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupSnapshotsJob do
  it "deletes snapshots older than 30 days" do
    create(:price_snapshot, captured_at: 31.days.ago)
    create(:price_snapshot, captured_at: 1.day.ago)

    expect { described_class.new.perform }.to change(PriceSnapshot, :count).by(-1)
  end

  it "does not delete recent snapshots" do
    create(:price_snapshot, captured_at: 1.hour.ago)

    expect { described_class.new.perform }.not_to change(PriceSnapshot, :count)
  end
end
