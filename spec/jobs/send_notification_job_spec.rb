# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendNotificationJob do
  let(:user) { create(:user) }

  it "calls Notifications::Manager with user and message" do
    manager = instance_double(Notifications::Manager)
    allow(Notifications::Manager).to receive(:new).and_return(manager)
    allow(manager).to receive(:notify)

    described_class.new.perform(user_id: user.id, message: "Test alert")

    expect(manager).to have_received(:notify).with(user: user, message: "Test alert", channels: nil)
  end

  it "discards when user not found" do
    expect { described_class.perform_now(user_id: 999999, message: "Test") }.not_to raise_error
  end
end
