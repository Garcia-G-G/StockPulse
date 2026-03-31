# frozen_string_literal: true

module Api
  module V1
    class WatchlistsController < BaseController
      def index
        items = current_user.watchlist_items.active
        render json: WatchlistItemSerializer.new(items).serializable_hash
      end

      def create
        item = current_user.watchlist_items.create!(watchlist_params)
        render json: WatchlistItemSerializer.new(item).serializable_hash, status: :created
      end

      def destroy
        item = current_user.watchlist_items.find(params[:id])
        item.destroy!
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
        params.require(:watchlist_item).permit(:symbol, :company_name, :exchange, :asset_type, :priority, :notes)
      end
    end
  end
end
