# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @watchlist_items = WatchlistItem.active.includes(:user).limit(50)
  end
end
