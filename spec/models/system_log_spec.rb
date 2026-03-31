# frozen_string_literal: true

require "rails_helper"

RSpec.describe SystemLog, type: :model do
  describe "validations" do
    it { should validate_presence_of(:level) }
    it { should validate_presence_of(:component) }
    it { should validate_presence_of(:message) }
    it { should validate_inclusion_of(:level).in_array(%w[info warning error critical]) }
  end

  describe ".log" do
    it "creates a log entry" do
      expect {
        SystemLog.log(level: "info", component: "test", message: "Test message")
      }.to change(SystemLog, :count).by(1)
    end

    it "stores details as jsonb" do
      log = SystemLog.log(level: "error", component: "test", message: "Error", details: { code: 500 })
      expect(log.details).to eq({ "code" => 500 })
    end
  end

  describe "scopes" do
    it ".errors returns error and critical logs" do
      info = create(:system_log, level: "info")
      error = create(:system_log, level: "error")
      critical = create(:system_log, level: "critical")

      errors = SystemLog.errors
      expect(errors).to include(error, critical)
      expect(errors).not_to include(info)
    end
  end
end
