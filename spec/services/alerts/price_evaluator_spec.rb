# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::PriceEvaluator, type: :service do
  let(:evaluator) { described_class.new }
  let(:user) { create(:user) }

  describe "price_above crossing detection" do
    let(:alert) { create(:alert, user: user, alert_type: "price_above", condition: { target_price: 200.0 }) }

    it "does not trigger without previous price" do
      result = evaluator.evaluate(alert, price_data: { close: 201.0 })
      expect(result).to be_nil
    end

    it "does not trigger when price stays below target" do
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "195.0") }
      result = evaluator.evaluate(alert, price_data: { close: 198.0 })
      expect(result).to be_nil
    end

    it "triggers when price crosses above target" do
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "198.0") }
      result = evaluator.evaluate(alert, price_data: { close: 201.0 })
      expect(result[:triggered]).to be true
      expect(result[:message]).to include("200.0")
    end

    it "does not re-trigger when price stays above target" do
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "201.0") }
      result = evaluator.evaluate(alert, price_data: { close: 205.0 })
      expect(result).to be_nil
    end
  end

  describe "price_below crossing detection" do
    let(:alert) { create(:alert, :price_below, user: user) }

    it "triggers when price crosses below target" do
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "155.0") }
      result = evaluator.evaluate(alert, price_data: { close: 148.0 })
      expect(result[:triggered]).to be true
    end
  end

  describe "price_range_break" do
    let(:alert) { create(:alert, :price_range_break, user: user) }

    it "triggers when price breaks out of range" do
      REDIS_POOL.with { |r| r.setex("alert_state:#{alert.id}:last_price", 3600, "190.0") }
      result = evaluator.evaluate(alert, price_data: { close: 210.0 })
      expect(result[:triggered]).to be true
      expect(result[:message]).to include("upper")
    end
  end
end
