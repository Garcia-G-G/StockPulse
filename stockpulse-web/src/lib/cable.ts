import { useEffect, useRef, useCallback } from "react";
import { useStore } from "./store";

const WS_URL = process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:3000/cable";

export function usePriceStream(symbol?: string) {
  const wsRef = useRef<WebSocket | null>(null);
  const updatePrice = useStore((s) => s.updatePrice);
  const setConnected = useStore((s) => s.setConnected);

  const connect = useCallback(() => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnected(true);
      const channel = symbol ? `prices:${symbol}` : "prices:all";
      ws.send(JSON.stringify({
        command: "subscribe",
        identifier: JSON.stringify({ channel: "PricesChannel", symbol: symbol || undefined }),
      }));
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type === "ping") return;
        if (data.message) {
          updatePrice(data.message);
        }
      } catch {
        // ignore parse errors
      }
    };

    ws.onclose = () => {
      setConnected(false);
      setTimeout(connect, 3000);
    };

    ws.onerror = () => {
      ws.close();
    };
  }, [symbol, updatePrice, setConnected]);

  useEffect(() => {
    connect();
    return () => { wsRef.current?.close(); };
  }, [connect]);
}
