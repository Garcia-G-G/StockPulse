# frozen_string_literal: true

# == Schema Information
#
# Table name: watchlist_items
#
#  id           :bigint           not null, primary key
#  asset_type   :string           default("stock"), not null
#  company_name :string           not null
#  exchange     :string(20)
#  is_active    :boolean          default(TRUE), not null
#  notes        :text
#  priority     :integer          default(3), not null
#  symbol       :string(10)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_watchlist_items_on_symbol                 (symbol)
#  index_watchlist_items_on_user_id                (user_id)
#  index_watchlist_items_on_user_id_and_is_active  (user_id,is_active)
#  index_watchlist_items_on_user_id_and_symbol     (user_id,symbol) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class WatchlistItem < ApplicationRecord
  ASSET_TYPES = %w[stock crypto etf].freeze

  belongs_to :user

  validates :symbol, presence: true, length: { maximum: 10 },
                     format: { with: /\A[A-Z0-9]+\z/, message: "must be uppercase alphanumeric" },
                     uniqueness: { scope: :user_id }
  validates :company_name, presence: true
  validates :asset_type, inclusion: { in: ASSET_TYPES }
  validates :priority, numericality: { only_integer: true, in: 1..5 }

  scope :active, -> { where(is_active: true) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :symbols, -> { active.distinct.pluck(:symbol) }

  before_validation :upcase_symbol

  def self.all_active_symbols
    active.distinct.pluck(:symbol)
  end

  def soft_delete!
    update!(is_active: false)
  end

  def active_alert_count
    user.alerts.enabled.for_symbol(symbol).count
  end

  private

  def upcase_symbol
    self.symbol = symbol&.upcase&.strip
  end
end
