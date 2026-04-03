"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePriceStream } from "@/lib/cable";
import { useStore } from "@/lib/store";
import { api, type WatchlistItem, type AlertHistory } from "@/lib/api";
import { PriceDisplay } from "@/components/data/PriceDisplay";
import { ChangePercent } from "@/components/data/ChangePercent";
import { SparklineChart } from "@/components/data/SparklineChart";
import { Bell, TrendingUp, BarChart3, Activity, Star } from "lucide-react";
import { formatPercent, timeAgo, ALERT_TYPE_EMOJIS } from "@/lib/utils";

export default function Dashboard() {
  const [watchlist, setWatchlist] = useState<WatchlistItem[]>([]);
  const [alertHistory, setAlertHistory] = useState<AlertHistory[]>([]);
  const [alertCount, setAlertCount] = useState(0);
  const prices = useStore((s) => s.prices);

  usePriceStream();

  useEffect(() => {
    api.getWatchlist().then((r) => setWatchlist(r.data)).catch(() => {});
    api.getAlertHistory().then((r) => {
      setAlertHistory(r.data.slice(0, 10));
      setAlertCount(r.data.length);
    }).catch(() => {});
  }, []);

  const totalChange = watchlist.reduce((sum, item) => {
    const price = prices[item.attributes.symbol];
    return sum + (price?.change_percent || 0);
  }, 0);
  const avgChange = watchlist.length > 0 ? totalChange / watchlist.length : 0;

  const highPriority = watchlist.filter((i) => i.attributes.priority >= 4);
  const medPriority = watchlist.filter((i) => i.attributes.priority === 3);
  const lowPriority = watchlist.filter((i) => i.attributes.priority <= 2);

  return (
    <div className="space-y-6">
      {/* Hero */}
      <div className="flex items-end justify-between">
        <div>
          <p className="label mb-1">Rendimiento del portafolio</p>
          <p className={`font-[family-name:var(--font-display)] text-5xl font-bold tracking-tight ${avgChange >= 0 ? "text-bull" : "text-bear"}`}>
            {formatPercent(avgChange)}
          </p>
          <p className="text-text-muted text-xs mt-1 flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-bull animate-pulse-dot" />
            {watchlist.length} activos monitoreados
          </p>
        </div>
        <div className="flex gap-3">
          {[
            { icon: Bell, label: "Alertas hoy", value: alertCount },
            { icon: Activity, label: "Símbolos", value: watchlist.length },
          ].map((stat) => (
            <div key={stat.label} className="bg-surface border border-border-subtle rounded px-4 py-3 min-w-[120px]">
              <div className="flex items-center gap-1.5 mb-1">
                <stat.icon className="w-3.5 h-3.5 text-text-muted" />
                <span className="label">{stat.label}</span>
              </div>
              <p className="font-[family-name:var(--font-display)] text-xl font-bold">{stat.value}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Ticker Strip */}
      <div className="overflow-hidden border-y border-border-subtle py-2 -mx-6 px-6">
        <div className="flex gap-8 animate-ticker whitespace-nowrap">
          {[...watchlist, ...watchlist].map((item, i) => {
            const price = prices[item.attributes.symbol];
            const pct = price?.change_percent;
            return (
              <span key={`${item.id}-${i}`} className="inline-flex items-center gap-2 text-sm">
                <span className="font-semibold text-text-primary">{item.attributes.symbol}</span>
                <span className="font-mono text-text-secondary">{price ? `$${price.price.toFixed(2)}` : "--"}</span>
                {pct != null && (
                  <span className={`font-mono text-xs ${pct >= 0 ? "text-bull" : "text-bear"}`}>
                    {pct >= 0 ? "▲" : "▼"}{Math.abs(pct).toFixed(2)}%
                  </span>
                )}
              </span>
            );
          })}
        </div>
      </div>

      {/* Main Grid */}
      <div className="grid grid-cols-12 gap-5">
        {/* Watchlist Cards */}
        <div className="col-span-12 lg:col-span-8 space-y-4">
          {/* High Priority — Large Cards */}
          {highPriority.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {highPriority.map((item) => (
                <Link
                  key={item.id}
                  href={`/watchlist/${item.attributes.symbol}`}
                  className="group bg-surface border border-border-subtle hover:border-amber/30 rounded-sm p-5 transition-all"
                >
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <div className="flex items-center gap-2">
                        <h3 className="font-[family-name:var(--font-display)] text-xl font-bold">{item.attributes.symbol}</h3>
                        <div className="flex gap-0.5">
                          {Array.from({ length: item.attributes.priority }).map((_, i) => (
                            <Star key={i} className="w-3 h-3 fill-amber text-amber" />
                          ))}
                        </div>
                      </div>
                      <p className="text-text-muted text-xs mt-0.5">{item.attributes.company_name}</p>
                    </div>
                    <ChangePercent value={prices[item.attributes.symbol]?.change_percent} size="lg" />
                  </div>
                  <PriceDisplay symbol={item.attributes.symbol} size="xl" />
                  <div className="mt-3">
                    <SparklineChart data={[190, 192, 191, 195, 193, 196, 195.5]} width={200} height={40} />
                  </div>
                </Link>
              ))}
            </div>
          )}

          {/* Medium Priority */}
          {medPriority.length > 0 && (
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
              {medPriority.map((item) => (
                <Link
                  key={item.id}
                  href={`/watchlist/${item.attributes.symbol}`}
                  className="bg-surface/60 border border-border-subtle hover:border-amber/20 rounded-sm p-4 transition-all"
                >
                  <div className="flex justify-between items-center mb-2">
                    <span className="font-[family-name:var(--font-display)] font-bold">{item.attributes.symbol}</span>
                    <ChangePercent value={prices[item.attributes.symbol]?.change_percent} size="sm" showIcon={false} />
                  </div>
                  <PriceDisplay symbol={item.attributes.symbol} size="md" />
                  <p className="text-text-muted text-[10px] mt-1 truncate">{item.attributes.company_name}</p>
                </Link>
              ))}
            </div>
          )}

          {/* Low Priority */}
          {lowPriority.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {lowPriority.map((item) => (
                <Link
                  key={item.id}
                  href={`/watchlist/${item.attributes.symbol}`}
                  className="inline-flex items-center gap-2 bg-surface/40 border border-border-subtle rounded-sm px-3 py-1.5 text-sm hover:border-amber/20 transition-all"
                >
                  <span className="font-semibold">{item.attributes.symbol}</span>
                  <PriceDisplay symbol={item.attributes.symbol} size="sm" />
                  <ChangePercent value={prices[item.attributes.symbol]?.change_percent} size="sm" showIcon={false} />
                </Link>
              ))}
            </div>
          )}

          {watchlist.length === 0 && (
            <div className="bg-surface border border-border-subtle rounded-sm p-12 text-center">
              <TrendingUp className="w-8 h-8 text-text-muted mx-auto mb-3" />
              <p className="text-text-secondary">Tu watchlist está vacía</p>
              <p className="text-text-muted text-sm mt-1">Agrega símbolos desde el bot de Telegram</p>
            </div>
          )}
        </div>

        {/* Alerts Feed */}
        <div className="col-span-12 lg:col-span-4">
          <div className="bg-surface/40 border border-border-subtle rounded-sm">
            <div className="px-4 py-3 border-b border-border-subtle flex items-center justify-between">
              <span className="label">Alertas recientes</span>
              <Link href="/alerts" className="text-xs text-amber hover:text-amber/80">Ver todas</Link>
            </div>
            <div className="divide-y divide-border-subtle max-h-[500px] overflow-y-auto">
              {alertHistory.length === 0 && (
                <div className="p-6 text-center text-text-muted text-sm">Sin alertas recientes</div>
              )}
              {alertHistory.map((alert) => (
                <div key={alert.id} className="px-4 py-3 hover:bg-surface-hover transition-colors animate-slide-in">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span>{ALERT_TYPE_EMOJIS[alert.attributes.alert_type] || "🔔"}</span>
                    <span className="font-semibold text-sm">{alert.attributes.symbol}</span>
                    <span className="text-text-muted text-xs ml-auto">{timeAgo(alert.attributes.triggered_at)}</span>
                  </div>
                  <p className="text-text-secondary text-xs">${alert.attributes.price_at_trigger?.toFixed(2)}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
