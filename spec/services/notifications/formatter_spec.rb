# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::Formatter do
  subject(:formatter) { described_class.new }

  describe "#format" do
    it "returns strings unchanged" do
      expect(formatter.format("Hello", channel: :telegram)).to eq("Hello")
    end

    it "formats hash for telegram with markdown" do
      msg = { title: "Alert", message: "Price moved", data: { price: 150 } }
      result = formatter.format(msg, channel: :telegram)
      expect(result).to include("*Alert*")
      expect(result).to include("Price moved")
      expect(result).to include("`150`")
    end

    it "formats hash for email with HTML" do
      msg = { title: "Alert", message: "Price moved" }
      result = formatter.format(msg, channel: :email)
      expect(result).to include("<h2>Alert</h2>")
      expect(result).to include("<p>Price moved</p>")
    end

    it "formats hash for whatsapp plainly" do
      msg = { title: "Alert", message: "Price moved", data: { price: 150 } }
      result = formatter.format(msg, channel: :whatsapp)
      expect(result).to include("*Alert*")
      expect(result).to include("price: 150")
    end
  end
end
