# frozen_string_literal: true

class WatchlistItem < ApplicationRecord
  belongs_to :user

  validates :symbol, presence: true, uniqueness: { scope: :user_id }
  validates :symbol, format: { with: /\A[A-Z0-9.]{1,10}\z/, message: "must be a valid ticker symbol" }

  scope :active, -> { where(active: true) }

  before_validation :upcase_symbol

  private

  def upcase_symbol
    self.symbol = symbol&.upcase
  end
end
