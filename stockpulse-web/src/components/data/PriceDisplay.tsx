"use client";
import { useStore } from "@/lib/store";
import { formatPrice } from "@/lib/utils";

interface PriceDisplayProps {
  symbol: string;
  fallbackPrice?: number;
  size?: "sm" | "md" | "lg" | "xl";
}

const SIZE_CLASSES = {
  sm: "text-sm",
  md: "text-lg",
  lg: "text-2xl",
  xl: "text-4xl font-bold",
};

export function PriceDisplay({ symbol, fallbackPrice, size = "md" }: PriceDisplayProps) {
  const livePrice = useStore((s) => s.prices[symbol]?.price);
  const flash = useStore((s) => s.flashStates[symbol]);
  const price = livePrice ?? fallbackPrice;

  return (
    <span
      data-price
      className={`${SIZE_CLASSES[size]} font-mono tabular-nums transition-colors ${
        flash === "up" ? "animate-flash-green" : flash === "down" ? "animate-flash-red" : ""
      }`}
    >
      {formatPrice(price)}
    </span>
  );
}
