"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { FileText, RefreshCw } from "lucide-react";

export default function BriefingPage() {
  const [briefing, setBriefing] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchBriefing = async () => {
    setLoading(true);
    try {
      const result = await api.getBriefing();
      setBriefing(result as Record<string, unknown>);
    } catch {
      setBriefing(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchBriefing(); }, []);

  return (
    <div className="space-y-6 max-w-3xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-[family-name:var(--font-display)] text-3xl font-bold">Briefing Diario</h1>
          <p className="text-text-muted text-sm mt-1">Resumen del mercado generado por IA</p>
        </div>
        <button onClick={fetchBriefing} disabled={loading} className="p-2 text-text-muted hover:text-amber transition-colors">
          <RefreshCw className={`w-5 h-5 ${loading ? "animate-spin" : ""}`} />
        </button>
      </div>

      {loading ? (
        <div className="bg-surface border border-border-subtle rounded-sm p-8 text-center">
          <FileText className="w-8 h-8 text-amber mx-auto mb-3 animate-pulse" />
          <p className="text-text-secondary">Generando briefing...</p>
        </div>
      ) : briefing ? (
        <div className="bg-surface border border-border-subtle rounded-sm p-6">
          <div className="prose-sm text-text-secondary leading-relaxed space-y-4">
            <p className="text-lg text-text-primary font-medium">{(briefing as Record<string, string>).market_summary || "Sin resumen disponible"}</p>
            <hr className="border-border-subtle" />
            <p className="text-text-muted text-xs italic">Generado con IA. Esto no es asesoramiento financiero.</p>
          </div>
        </div>
      ) : (
        <div className="bg-surface/40 border border-border-subtle rounded-sm p-12 text-center text-text-muted">
          No se pudo cargar el briefing
        </div>
      )}
    </div>
  );
}
