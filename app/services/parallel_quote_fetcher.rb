# frozen_string_literal: true

# Fetches Finnhub quotes for many symbols in parallel using a bounded thread
# pool. Uses Ruby stdlib only — no extra gems. Bounded by MAX_CONCURRENT so we
# don't stampede the upstream API, and by TIMEOUT_SECONDS so a slow upstream
# can't tie up a Puma worker.
class ParallelQuoteFetcher
  MAX_CONCURRENT  = 10
  TIMEOUT_SECONDS = 5
  OPEN_TIMEOUT    = 3
  READ_TIMEOUT    = 3

  def initialize(api_key: ENV.fetch("FINNHUB_API_KEY", nil))
    @api_key = api_key
  end

  # Returns: { "AAPL" => { price:, change_percent:, ... }, ... }
  # Missing/failed symbols are simply omitted from the result hash.
  def fetch(symbols)
    symbols = Array(symbols).compact.uniq.first(MAX_CONCURRENT)
    return {} if symbols.empty? || @api_key.to_s.empty?

    results = {}
    mutex = Mutex.new
    deadline = monotonic_now + TIMEOUT_SECONDS

    threads = symbols.map do |symbol|
      Thread.new do
        begin
          quote = fetch_single(symbol, deadline: deadline)
          mutex.synchronize { results[symbol] = quote } if quote
        rescue StandardError => e
          Rails.logger.warn("[ParallelQuoteFetcher] #{symbol} failed: #{e.class}: #{e.message}")
        end
      end
    end

    threads.each do |t|
      remaining = [deadline - monotonic_now, 0.1].max
      unless t.join(remaining)
        t.kill
        Rails.logger.warn("[ParallelQuoteFetcher] thread timed out")
      end
    end

    results
  end

  private

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def fetch_single(symbol, deadline:)
    encoded = CGI.escape(symbol)
    uri = URI("https://finnhub.io/api/v1/quote?symbol=#{encoded}&token=#{@api_key}")

    remaining = deadline - monotonic_now
    return nil if remaining <= 0

    response = Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: true,
      open_timeout: [OPEN_TIMEOUT, remaining].min,
      read_timeout: [READ_TIMEOUT, remaining].min
    ) do |http|
      http.get(uri.request_uri)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    current = data["c"].to_f
    return nil if current <= 0

    {
      price: current,
      change: data["d"].to_f,
      change_percent: data["dp"].to_f,
      high: data["h"].to_f,
      low: data["l"].to_f,
      open: data["o"].to_f,
      previous_close: data["pc"].to_f,
      fetched_at: Time.current.iso8601
    }
  end
end
