import { create } from "zustand";
import type { PriceUpdate, WatchlistItem, Alert } from "./api";

interface PriceState {
  prices: Record<string, PriceUpdate>;
  previousPrices: Record<string, number>;
  flashStates: Record<string, "up" | "down" | null>;
  connected: boolean;
  watchlist: WatchlistItem[];
  alerts: Alert[];
}

interface PriceActions {
  updatePrice: (update: PriceUpdate) => void;
  setConnected: (connected: boolean) => void;
  setWatchlist: (items: WatchlistItem[]) => void;
  setAlerts: (alerts: Alert[]) => void;
  clearFlash: (symbol: string) => void;
}

export const useStore = create<PriceState & PriceActions>((set, get) => ({
  prices: {},
  previousPrices: {},
  flashStates: {},
  connected: false,
  watchlist: [],
  alerts: [],

  updatePrice: (update: PriceUpdate) => {
    const prev = get().prices[update.symbol]?.price;
    const direction = prev && update.price > prev ? "up" : prev && update.price < prev ? "down" : null;

    set((state) => ({
      prices: { ...state.prices, [update.symbol]: update },
      previousPrices: prev ? { ...state.previousPrices, [update.symbol]: prev } : state.previousPrices,
      flashStates: direction ? { ...state.flashStates, [update.symbol]: direction } : state.flashStates,
    }));

    if (direction) {
      setTimeout(() => {
        set((state) => ({
          flashStates: { ...state.flashStates, [update.symbol]: null },
        }));
      }, 600);
    }
  },

  setConnected: (connected) => set({ connected }),
  setWatchlist: (watchlist) => set({ watchlist }),
  setAlerts: (alerts) => set({ alerts }),
  clearFlash: (symbol) => set((state) => ({
    flashStates: { ...state.flashStates, [symbol]: null },
  })),
}));
