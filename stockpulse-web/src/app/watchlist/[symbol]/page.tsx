"use client";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { usePriceStream } from "@/lib/cable";
import { useStore } from "@/lib/store";
import { PriceDisplay } from "@/components/data/PriceDisplay";
import { ChangePercent } from "@/components/data/ChangePercent";
import { SentimentBadge } from "@/components/data/SentimentBadge";
import { api } from "@/lib/api";
import { ArrowLeft, Plus } from "lucide-react";
import Link from "next/link";

export default function WatchlistDetail() {
  const params = useParams();
  const symbol = (params.symbol as string)?.toUpperCase();
  const price = useStore((s) => s.prices[symbol]);
  const [analysis, setAnalysis] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(false);

  usePriceStream(symbol);

  useEffect(() => {
    if (!symbol) return;
    setLoading(true);
    api.getAnalysisOverview(symbol)
      .then((r) => setAnalysis(r as Record<string, unknown>))
      .catch(() => setAnalysis(null))
      .finally(() => setLoading(false));
  }, [symbol]);

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href="/" className="text-text-muted hover:text-text-primary transition-colors">
          <ArrowLeft className="w-5 h-5" />
        </Link>
        <div>
          <h1 className="font-[family-name:var(--font-display)] text-3xl font-bold">{symbol}</h1>
          <p className="text-text-muted text-sm">Detalle del símbolo</p>
        </div>
      </div>

      <div className="grid grid-cols-12 gap-6">
        {/* Price Section */}
        <div className="col-span-12 lg:col-span-8">
          <div className="bg-surface border border-border-subtle rounded-sm p-6">
            <div className="flex items-end justify-between mb-6">
              <div>
                <p className="label mb-1">Precio actual</p>
                <PriceDisplay symbol={symbol} size="xl" />
              </div>
              <ChangePercent value={price?.change_percent} size="lg" />
            </div>

            {/* Chart placeholder */}
            <div className="h-[400px] bg-navy-lighter rounded flex items-center justify-center border border-border-subtle">
              <div className="text-center text-text-muted">
                <p className="text-sm">Gráfico de velas</p>
                <p className="text-xs mt-1">Conecte API de datos para gráficos en tiempo real</p>
              </div>
            </div>

            <div className="flex gap-2 mt-4">
              {["1D", "1S", "1M", "3M", "1A"].map((tf) => (
                <button key={tf} className="px-3 py-1 text-xs font-medium rounded bg-surface-hover text-text-secondary hover:text-text-primary hover:bg-amber-dim transition-colors">
                  {tf}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Info Panel */}
        <div className="col-span-12 lg:col-span-4 space-y-4">
          {/* Quote Details */}
          <div className="bg-surface border border-border-subtle rounded-sm p-4">
            <p className="label mb-3">Datos de mercado</p>
            <div className="space-y-2.5">
              {[
                { label: "Apertura", value: price?.open },
                { label: "Máximo", value: price?.high },
                { label: "Mínimo", value: price?.low },
                { label: "VWAP", value: price?.vwap },
                { label: "Volumen", value: price?.volume },
              ].map(({ label, value }) => (
                <div key={label} className="flex justify-between items-center">
                  <span className="text-text-muted text-sm">{label}</span>
                  <span className="font-mono text-sm">{value != null ? (typeof value === "number" && value > 1000 ? `${(value/1000).toFixed(1)}K` : `$${Number(value).toFixed(2)}`) : "--"}</span>
                </div>
              ))}
            </div>
          </div>

          {/* AI Analysis */}
          <div className="bg-surface border border-border-subtle rounded-sm p-4">
            <div className="flex items-center justify-between mb-3">
              <p className="label">Análisis IA</p>
              {analysis && <SentimentBadge sentiment={(analysis as Record<string, string>).sentiment || "neutral"} />}
            </div>
            {loading ? (
              <div className="space-y-2">
                <div className="h-3 bg-navy-lighter rounded animate-pulse w-full" />
                <div className="h-3 bg-navy-lighter rounded animate-pulse w-3/4" />
                <div className="h-3 bg-navy-lighter rounded animate-pulse w-5/6" />
              </div>
            ) : analysis ? (
              <p className="text-text-secondary text-sm leading-relaxed">{(analysis as Record<string, string>).summary || "Análisis no disponible"}</p>
            ) : (
              <p className="text-text-muted text-sm">Análisis no disponible para este símbolo</p>
            )}
          </div>

          {/* Quick Actions */}
          <div className="bg-surface border border-border-subtle rounded-sm p-4">
            <p className="label mb-3">Acciones rápidas</p>
            <div className="space-y-2">
              <Link href="/alerts" className="flex items-center gap-2 w-full px-3 py-2 text-sm bg-amber-dim text-amber rounded hover:bg-amber/20 transition-colors">
                <Plus className="w-4 h-4" /> Crear alerta para {symbol}
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
