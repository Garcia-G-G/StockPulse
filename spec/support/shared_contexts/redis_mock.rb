# frozen_string_literal: true

RSpec.shared_context "with clean redis" do
  before do
    REDIS_POOL.with do |redis|
      redis.flushdb
    end
  rescue Redis::CannotConnectError
    skip "Redis not available"
  end
end
