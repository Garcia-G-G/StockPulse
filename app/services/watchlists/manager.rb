# frozen_string_literal: true

module Watchlists
  class Manager
    def add(user:, symbol:, name: nil, exchange: nil)
      item = user.watchlist_items.find_or_initialize_by(symbol: symbol.upcase)
      item.assign_attributes(name: name, exchange: exchange, active: true, added_at: Time.current)
      item.save!
      item
    end

    def remove(user:, symbol:)
      item = user.watchlist_items.find_by!(symbol: symbol.upcase)
      item.update!(active: false)
      item
    end

    def all_watched_symbols
      WatchlistItem.active.distinct.pluck(:symbol)
    end
  end
end
