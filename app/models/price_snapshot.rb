# frozen_string_literal: true

class PriceSnapshot < ApplicationRecord
  validates :symbol, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :captured_at, presence: true

  scope :for_symbol, ->(symbol) { where(symbol: symbol.upcase) }
  scope :recent, -> { order(captured_at: :desc) }
  scope :older_than, ->(time) { where("captured_at < ?", time) }

  before_validation :upcase_symbol

  private

  def upcase_symbol
    self.symbol = symbol&.upcase
  end
end
