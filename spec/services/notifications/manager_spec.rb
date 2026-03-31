# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::Manager, type: :service do
  let(:manager) { described_class.new }
  let(:user) { create(:user) }
  let(:alert) { create(:alert, user: user) }
  let(:price_data) { { close: 201.0, change_percent: 3.0, volume: 1_000_000 } }

  describe "#dispatch" do
    before do
      allow_any_instance_of(Notifications::TelegramSender).to receive(:send_notification)
        .and_return({ message_id: "123" })
      allow_any_instance_of(Notifications::EmailSender).to receive(:send_notification)
        .and_return({ message_id: "abc" })
    end

    it "dispatches to all enabled channels" do
      results = manager.dispatch(user: user, alert: alert, aggregated_price: price_data)
      channels = results.map { |r| r[:channel] }
      expect(channels).to include(:telegram)
    end

    it "returns success status for each channel" do
      results = manager.dispatch(user: user, alert: alert, aggregated_price: price_data)
      expect(results.first[:success]).to be true
    end

    context "when all channels fail" do
      before do
        allow_any_instance_of(Notifications::TelegramSender).to receive(:send_notification)
          .and_raise(StandardError, "Connection refused")
        allow_any_instance_of(Notifications::EmailSender).to receive(:send_notification)
          .and_raise(StandardError, "SMTP error")
      end

      it "creates a critical SystemLog entry" do
        expect { manager.dispatch(user: user, alert: alert, aggregated_price: price_data) }
          .to change { SystemLog.where(level: "critical").count }.by(1)
      end
    end
  end
end
