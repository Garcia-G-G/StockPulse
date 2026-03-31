# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Health", type: :request do
  describe "GET /api/v1/health" do
    it "returns health status structure" do
      get "/api/v1/health"
      expect(response.status).to be_in([ 200, 503 ])
      body = JSON.parse(response.body)
      expect(body).to have_key("status")
      expect(body).to have_key("database")
      expect(body).to have_key("redis")
    end
  end
end
