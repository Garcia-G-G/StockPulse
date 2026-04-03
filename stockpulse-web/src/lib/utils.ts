import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import numeral from "numeral";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatPrice(value: number | null | undefined): string {
  if (value == null) return "--";
  return numeral(value).format("$0,0.00");
}

export function formatChange(value: number | null | undefined): string {
  if (value == null) return "--";
  const sign = value >= 0 ? "+" : "";
  return `${sign}${numeral(value).format("0.00")}`;
}

export function formatPercent(value: number | null | undefined): string {
  if (value == null) return "--";
  const sign = value >= 0 ? "+" : "";
  return `${sign}${numeral(value).format("0.00")}%`;
}

export function formatVolume(value: number | null | undefined): string {
  if (value == null) return "--";
  return numeral(value).format("0.0a").toUpperCase();
}

export function formatNumber(value: number | null | undefined): string {
  if (value == null) return "--";
  return numeral(value).format("0,0");
}

export function timeAgo(date: string | Date): string {
  const now = new Date();
  const then = new Date(date);
  const seconds = Math.floor((now.getTime() - then.getTime()) / 1000);
  if (seconds < 60) return `hace ${seconds}s`;
  if (seconds < 3600) return `hace ${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `hace ${Math.floor(seconds / 3600)}h`;
  return `hace ${Math.floor(seconds / 86400)}d`;
}

export const ALERT_TYPE_LABELS: Record<string, string> = {
  price_above: "Precio por encima",
  price_below: "Precio por debajo",
  percent_change_up: "Cambio % alcista",
  percent_change_down: "Cambio % bajista",
  price_range_break: "Ruptura de rango",
  volume_spike: "Pico de volumen",
  volume_dry: "Volumen seco",
  rsi_overbought: "RSI sobrecompra",
  rsi_oversold: "RSI sobreventa",
  macd_crossover_bullish: "MACD alcista",
  macd_crossover_bearish: "MACD bajista",
  bollinger_break_upper: "Bollinger superior",
  bollinger_break_lower: "Bollinger inferior",
  sma_golden_cross: "Cruce dorado",
  sma_death_cross: "Cruce de la muerte",
  news_high_impact: "Noticia alto impacto",
};

export const ALERT_TYPE_EMOJIS: Record<string, string> = {
  price_above: "📈", price_below: "📉",
  percent_change_up: "🚀", percent_change_down: "📉",
  price_range_break: "📊",
  volume_spike: "📢", volume_dry: "🏜️",
  rsi_overbought: "🔥", rsi_oversold: "❄️",
  macd_crossover_bullish: "⬆️", macd_crossover_bearish: "⬇️",
  bollinger_break_upper: "🌊", bollinger_break_lower: "🌊",
  sma_golden_cross: "⭐", sma_death_cross: "💀",
  news_high_impact: "📰",
};
