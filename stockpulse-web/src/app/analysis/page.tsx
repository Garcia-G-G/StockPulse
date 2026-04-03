"use client";
import { useState } from "react";
import { api } from "@/lib/api";
import { SentimentBadge } from "@/components/data/SentimentBadge";
import { Search, Brain } from "lucide-react";

export default function AnalysisPage() {
  const [symbol, setSymbol] = useState("");
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSearch = async () => {
    if (!symbol) return;
    setLoading(true);
    try {
      const result = await api.getAnalysisOverview(symbol.toUpperCase());
      setData(result as Record<string, unknown>);
    } catch {
      setData(null);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-[family-name:var(--font-display)] text-3xl font-bold">Análisis</h1>
        <p className="text-text-muted text-sm mt-1">Análisis técnico y fundamental con IA</p>
      </div>

      <div className="flex gap-2 max-w-md">
        <input
          type="text"
          value={symbol}
          onChange={(e) => setSymbol(e.target.value.toUpperCase())}
          onKeyDown={(e) => e.key === "Enter" && handleSearch()}
          placeholder="Ingresa un símbolo (AAPL, TSLA...)"
          className="flex-1 bg-surface border border-border-subtle rounded px-4 py-2.5 text-sm text-text-primary focus:border-amber focus:outline-none"
        />
        <button
          onClick={handleSearch}
          disabled={loading}
          className="px-4 py-2.5 bg-amber text-navy font-semibold rounded text-sm hover:bg-amber/90 disabled:opacity-50 flex items-center gap-2"
        >
          {loading ? <Brain className="w-4 h-4 animate-spin" /> : <Search className="w-4 h-4" />}
          Analizar
        </button>
      </div>

      {loading && (
        <div className="bg-surface border border-border-subtle rounded-sm p-8 text-center">
          <Brain className="w-8 h-8 text-amber mx-auto mb-3 animate-pulse" />
          <p className="text-text-secondary">Analizando {symbol} con Gemini...</p>
        </div>
      )}

      {data && !loading && (
        <div className="bg-surface border border-border-subtle rounded-sm p-6 space-y-4">
          <div className="flex items-center gap-3">
            <h2 className="font-[family-name:var(--font-display)] text-xl font-bold">{symbol}</h2>
            <SentimentBadge sentiment={(data as Record<string, string>).sentiment || "neutral"} />
          </div>
          <p className="text-text-secondary leading-relaxed">{(data as Record<string, string>).summary || "Sin resumen disponible"}</p>
          <p className="text-text-muted text-xs italic">Esto no es asesoramiento financiero.</p>
        </div>
      )}

      {!data && !loading && (
        <div className="bg-surface/40 border border-border-subtle rounded-sm p-12 text-center">
          <Brain className="w-10 h-10 text-text-muted mx-auto mb-3" />
          <p className="text-text-secondary">Busca un símbolo para obtener análisis IA</p>
        </div>
      )}
    </div>
  );
}
