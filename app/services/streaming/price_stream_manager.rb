# frozen_string_literal: true

module Streaming
  class PriceStreamManager
    def start
      raise NotImplementedError, "PriceStreamManager#start not yet implemented"
    end

    def stop
      raise NotImplementedError, "PriceStreamManager#stop not yet implemented"
    end

    def subscribe(symbol)
      raise NotImplementedError, "PriceStreamManager#subscribe not yet implemented"
    end

    def unsubscribe(symbol)
      raise NotImplementedError, "PriceStreamManager#unsubscribe not yet implemented"
    end
  end
end
