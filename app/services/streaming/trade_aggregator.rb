# frozen_string_literal: true

module Streaming
  class TradeAggregator
    def aggregate(trades)
      raise NotImplementedError, "TradeAggregator#aggregate not yet implemented"
    end
  end
end
