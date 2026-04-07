# frozen_string_literal: true

class CleanupSnapshotsJob < ApplicationJob
  queue_as :low

  BATCH_SIZE = 10_000

  def perform
    cutoff = 30.days.ago
    total_deleted = 0

    # Delete in batches to avoid long-running table locks
    loop do
      batch_deleted = PriceSnapshot.older_than(cutoff).limit(BATCH_SIZE).delete_all
      total_deleted += batch_deleted
      break if batch_deleted < BATCH_SIZE
    end
    SystemLog.log(level: "info", component: "cleanup", message: "Deleted #{total_deleted} price snapshots older than #{cutoff.iso8601}")

    old_logs = 0
    loop do
      batch = SystemLog.where("created_at < ?", 90.days.ago).limit(BATCH_SIZE).delete_all
      old_logs += batch
      break if batch < BATCH_SIZE
    end
    SystemLog.log(level: "info", component: "cleanup", message: "Deleted #{old_logs} system logs older than 90 days")
  rescue StandardError => e
    SystemLog.log(level: "error", component: "cleanup", message: "Failed: #{e.message}")
  end
end
