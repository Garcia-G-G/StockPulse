# frozen_string_literal: true

class CleanupSnapshotsJob < ApplicationJob
  queue_as :low

  def perform
    cutoff = 30.days.ago
    deleted = PriceSnapshot.older_than(cutoff).delete_all
    SystemLog.log(level: "info", component: "cleanup", message: "Deleted #{deleted} price snapshots older than #{cutoff.iso8601}")

    old_logs = SystemLog.where("created_at < ?", 90.days.ago).delete_all
    SystemLog.log(level: "info", component: "cleanup", message: "Deleted #{old_logs} system logs older than 90 days")
  rescue StandardError => e
    SystemLog.log(level: "error", component: "cleanup", message: "Failed: #{e.message}")
  end
end
