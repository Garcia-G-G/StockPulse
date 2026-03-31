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
class WatchlistItemSerializer
  include JSONAPI::Serializer

  attributes :symbol, :company_name, :exchange, :asset_type, :priority, :is_active, :created_at
end
