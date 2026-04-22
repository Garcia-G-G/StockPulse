# frozen_string_literal: true

module Api
  module V1
    class WatchlistsController < BaseController
      def index
        payload = Rails.cache.fetch(watchlist_cache_key, expires_in: 10.seconds) do
          items = current_user.watchlist_items.active.to_a
          WatchlistItemSerializer.new(items).serializable_hash
        end
        render json: payload
      end

      def create
        item = current_user.watchlist_items.create!(watchlist_params)
        Rails.cache.delete(watchlist_cache_key)
        render json: WatchlistItemSerializer.new(item).serializable_hash, status: :created
      end

      def destroy
        item = current_user.watchlist_items.find(params[:id])
        item.destroy!
        Rails.cache.delete(watchlist_cache_key)
        head :no_content
      end

      def quote
        item = current_user.watchlist_items.find(params[:id])
        quote_data = FinnhubClient.new.quote(item.symbol)
        render json: QuoteSerializer.new(
          OpenStruct.new(quote_data.merge(id: item.id, symbol: item.symbol))
        ).serializable_hash
      end

      private

      def watchlist_params
        params.require(:watchlist_item).permit(:symbol, :name, :exchange)
      end

      def watchlist_cache_key
        "watchlist:#{current_user.id}"
      end
    end
  end
end
