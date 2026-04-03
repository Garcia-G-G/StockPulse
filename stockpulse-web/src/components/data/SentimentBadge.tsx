interface SentimentBadgeProps {
  sentiment: "bullish" | "bearish" | "neutral" | string;
}

const CONFIGS: Record<string, { label: string; bg: string; text: string }> = {
  bullish: { label: "Alcista", bg: "bg-bull-dim", text: "text-bull" },
  bearish: { label: "Bajista", bg: "bg-bear-dim", text: "text-bear" },
  neutral: { label: "Neutral", bg: "bg-surface", text: "text-text-secondary" },
};

export function SentimentBadge({ sentiment }: SentimentBadgeProps) {
  const config = CONFIGS[sentiment] || CONFIGS.neutral;
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded text-xs font-medium ${config.bg} ${config.text}`}>
      {config.label}
    </span>
  );
}
