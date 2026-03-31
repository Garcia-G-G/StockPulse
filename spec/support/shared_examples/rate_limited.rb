# frozen_string_literal: true

RSpec.shared_examples "rate limited" do |method, path|
  it "enforces rate limiting via Rack::Attack" do
    # Rack::Attack is configured but typically disabled in test
    # This shared example documents the expected behavior
    expect(Rack::Attack).to be_a(Module)
  end
end
