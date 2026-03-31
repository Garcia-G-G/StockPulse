# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::Engine, type: :service do
  let(:engine) { described_class.new }
  let(:user) { create(:user) }
  let(:alert) { create(:alert, user: user, symbol: "AAPL") }
  let(:price_data) { { symbol: "AAPL", close: 201.0, change_percent: 3.0, volume: 1_000_000 } }

  before do
    # Seed last_price so crossing detection works
    REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "195.0") }
  end

  describe "#evaluate" do
    it "routes price alerts to PriceEvaluator" do
      expect_any_instance_of(Alerts::PriceEvaluator).to receive(:evaluate).and_call_original
      engine.evaluate(price_data)
    end

    it "creates AlertHistory when alert triggers" do
      expect { engine.evaluate(price_data) }.to change(AlertHistory, :count).by(1)
    end

    it "enqueues SendNotificationJob when alert triggers" do
      ActiveJob::Base.queue_adapter = :test
      expect { engine.evaluate(price_data) }.to have_enqueued_job(SendNotificationJob)
    end

    context "anti-spam: cooldown" do
      it "blocks alerts in cooldown" do
        alert.update!(last_triggered_at: 5.minutes.ago)
        expect { engine.evaluate(price_data) }.not_to change(AlertHistory, :count)
      end
    end

    context "anti-spam: muted user" do
      it "blocks alerts for muted users" do
        user.mute!(60)
        expect { engine.evaluate(price_data) }.not_to change(AlertHistory, :count)
      end
    end

    context "anti-spam: rate limit" do
      it "blocks when user exceeds max alerts per minute" do
        key = "user_alerts:#{user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
        REDIS_POOL.with { |r| r.set(key, "10"); r.expire(key, 120) }
        expect { engine.evaluate(price_data) }.not_to change(AlertHistory, :count)
      end
    end

    context "anti-spam: dedup" do
      it "blocks duplicate triggers within 5 minutes" do
        engine.evaluate(price_data)
        # Reset last_price for another crossing
        REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "195.0") }
        alert.update!(last_triggered_at: nil, trigger_count: 0)
        # Second trigger with same data should be deduped
        expect { engine.evaluate(price_data) }.not_to change(AlertHistory, :count)
      end
    end

    it "auto-disables one-time alerts after triggering" do
      alert.update!(is_one_time: true)
      engine.evaluate(price_data)
      expect(alert.reload.is_enabled).to be false
    end
  end
end
