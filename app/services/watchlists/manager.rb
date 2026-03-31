# frozen_string_literal: true

module Watchlists
  class Manager
    def add(user:, symbol:, name: nil, exchange: nil)
      raise NotImplementedError, "Watchlists::Manager#add not yet implemented"
    end

    def remove(user:, symbol:)
      raise NotImplementedError, "Watchlists::Manager#remove not yet implemented"
    end

    def all_watched_symbols
      WatchlistItem.active.distinct.pluck(:symbol)
    end
  end
end
