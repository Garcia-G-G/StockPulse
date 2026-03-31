# frozen_string_literal: true

# Puma configuration optimized for Hetzner CX22 (2 vCPU, 4 GB RAM)

max_threads = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
min_threads = ENV.fetch("RAILS_MIN_THREADS", max_threads).to_i
threads min_threads, max_threads

workers ENV.fetch("WEB_CONCURRENCY", 2).to_i

preload_app!

bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

environment ENV.fetch("RAILS_ENV", "development")

pidfile ENV.fetch("PIDFILE", "tmp/pids/puma.pid")
state_path ENV.fetch("STATEFILE", "tmp/pids/puma.state")

# Allow puma to be restarted by `bin/rails restart`
plugin :tmp_restart

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
