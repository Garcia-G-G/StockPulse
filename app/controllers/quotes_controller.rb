class QuotesController < ApplicationController
  layout "landing"

  def show
    @symbol = params[:symbol].to_s.strip.upcase
    api_key = ENV["FINNHUB_API_KEY"]

    # Fetch quote
    @quote = Rails.cache.fetch("finnhub_quote_#{@symbol}", expires_in: 2.minutes) do
      resp = Faraday.get("https://finnhub.io/api/v1/quote?symbol=#{@symbol}&token=#{api_key}")
      JSON.parse(resp.body)
    rescue
      nil
    end

    # Fetch company profile
    @profile = Rails.cache.fetch("finnhub_profile_#{@symbol}", expires_in: 1.hour) do
      resp = Faraday.get("https://finnhub.io/api/v1/stock/profile2?symbol=#{@symbol}&token=#{api_key}")
      JSON.parse(resp.body)
    rescue
      nil
    end

    redirect_to root_path, alert: "Symbol not found" if @quote.nil? || @quote["c"].to_f.zero?
  end
end
