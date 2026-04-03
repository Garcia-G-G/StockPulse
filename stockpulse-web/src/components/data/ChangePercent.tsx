import { formatPercent } from "@/lib/utils";
import { TrendingUp, TrendingDown, Minus } from "lucide-react";

interface ChangePercentProps {
  value: number | null | undefined;
  size?: "sm" | "md" | "lg";
  showIcon?: boolean;
}

const SIZE_CLASSES = {
  sm: "text-xs",
  md: "text-sm",
  lg: "text-lg font-semibold",
};

export function ChangePercent({ value, size = "md", showIcon = true }: ChangePercentProps) {
  if (value == null) return <span className={`${SIZE_CLASSES[size]} text-text-muted`}>--</span>;

  const isPositive = value >= 0;
  const Icon = value > 0 ? TrendingUp : value < 0 ? TrendingDown : Minus;

  return (
    <span className={`${SIZE_CLASSES[size]} inline-flex items-center gap-1 font-mono ${
      isPositive ? "text-bull" : "text-bear"
    }`}>
      {showIcon && <Icon className="w-3.5 h-3.5" />}
      {formatPercent(value)}
    </span>
  );
}
