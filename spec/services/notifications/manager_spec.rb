# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::Manager do
  subject(:manager) { described_class.new }

  let(:user) { create(:user, telegram_chat_id: "123", email: "test@example.com") }

  describe "#notify" do
    it "sends to all user channels" do
      telegram = instance_double(Notifications::TelegramSender)
      email = instance_double(Notifications::EmailSender)

      allow(Notifications::TelegramSender).to receive(:new).and_return(telegram)
      allow(Notifications::EmailSender).to receive(:new).and_return(email)
      allow(telegram).to receive(:send_message)
      allow(email).to receive(:send_message)

      manager.notify(user: user, message: "Test")

      expect(telegram).to have_received(:send_message).with(user: user, message: "Test")
      expect(email).to have_received(:send_message).with(user: user, message: "Test")
    end

    it "skips notification when user is muted" do
      user.update!(notifications_muted: true)

      expect(Notifications::TelegramSender).not_to receive(:new)
      expect(Notifications::EmailSender).not_to receive(:new)

      manager.notify(user: user, message: "Test")
    end

    it "logs errors without raising" do
      allow(Notifications::TelegramSender).to receive(:new).and_raise(StandardError, "Connection failed")

      expect { manager.notify(user: user, message: "Test") }.not_to raise_error
    end
  end
end
