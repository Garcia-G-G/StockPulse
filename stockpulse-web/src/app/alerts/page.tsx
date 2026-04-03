"use client";
import { useEffect, useState } from "react";
import { api, type Alert, type AlertHistory } from "@/lib/api";
import { ALERT_TYPE_LABELS, ALERT_TYPE_EMOJIS, timeAgo } from "@/lib/utils";
import { Bell, History, Plus, Trash2, Pause } from "lucide-react";

type Tab = "active" | "history" | "create";

export default function AlertsPage() {
  const [tab, setTab] = useState<Tab>("active");
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [history, setHistory] = useState<AlertHistory[]>([]);

  useEffect(() => {
    api.getAlerts().then((r) => setAlerts(r.data)).catch(() => {});
    api.getAlertHistory().then((r) => setHistory(r.data)).catch(() => {});
  }, []);

  const handleDelete = async (id: string) => {
    await api.deleteAlert(id);
    setAlerts((prev) => prev.filter((a) => a.id !== id));
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-[family-name:var(--font-display)] text-3xl font-bold">Alertas</h1>
        <p className="text-text-muted text-sm mt-1">Gestiona tus alertas de mercado</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-surface rounded p-1 w-fit">
        {([
          { key: "active", label: "Activas", icon: Bell },
          { key: "history", label: "Historial", icon: History },
          { key: "create", label: "Crear", icon: Plus },
        ] as const).map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex items-center gap-1.5 px-4 py-2 text-sm rounded transition-colors ${
              tab === key ? "bg-amber-dim text-amber" : "text-text-secondary hover:text-text-primary"
            }`}
          >
            <Icon className="w-4 h-4" />
            {label}
          </button>
        ))}
      </div>

      {/* Active Alerts */}
      {tab === "active" && (
        <div className="space-y-2">
          {alerts.length === 0 && (
            <div className="bg-surface border border-border-subtle rounded-sm p-12 text-center">
              <Bell className="w-8 h-8 text-text-muted mx-auto mb-3" />
              <p className="text-text-secondary">No tienes alertas activas</p>
            </div>
          )}
          {alerts.map((alert) => (
            <div key={alert.id} className="bg-surface border border-border-subtle rounded-sm p-4 flex items-center gap-4">
              <span className="text-2xl">{ALERT_TYPE_EMOJIS[alert.attributes.alert_type] || "🔔"}</span>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="font-[family-name:var(--font-display)] font-bold">{alert.attributes.symbol}</span>
                  <span className="text-text-muted text-xs">{ALERT_TYPE_LABELS[alert.attributes.alert_type]}</span>
                </div>
                <p className="text-text-muted text-xs mt-0.5">
                  Disparada {alert.attributes.trigger_count}x · Cooldown: {alert.attributes.cooldown_minutes}min
                </p>
              </div>
              <div className="flex gap-2">
                <button onClick={() => handleDelete(alert.id)} className="p-2 text-text-muted hover:text-bear transition-colors">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* History */}
      {tab === "history" && (
        <div className="space-y-2">
          {history.length === 0 && (
            <div className="bg-surface border border-border-subtle rounded-sm p-12 text-center text-text-muted">Sin historial</div>
          )}
          {history.map((h) => (
            <div key={h.id} className="bg-surface/60 border border-border-subtle rounded-sm p-4 flex items-center gap-4 animate-slide-in">
              <span>{ALERT_TYPE_EMOJIS[h.attributes.alert_type] || "🔔"}</span>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-semibold text-sm">{h.attributes.symbol}</span>
                  <span className="text-text-muted text-xs">{ALERT_TYPE_LABELS[h.attributes.alert_type]}</span>
                </div>
                <p className="text-text-muted text-xs">
                  ${h.attributes.price_at_trigger?.toFixed(2)} · {timeAgo(h.attributes.triggered_at)}
                </p>
              </div>
              {h.attributes.ai_analysis && (
                <p className="text-text-secondary text-xs max-w-xs truncate">{h.attributes.ai_analysis}</p>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Create */}
      {tab === "create" && (
        <CreateAlertForm onCreated={(a) => { setAlerts((prev) => [...prev, a]); setTab("active"); }} />
      )}
    </div>
  );
}

function CreateAlertForm({ onCreated }: { onCreated: (a: Alert) => void }) {
  const [symbol, setSymbol] = useState("");
  const [alertType, setAlertType] = useState("price_above");
  const [condition, setCondition] = useState<Record<string, unknown>>({ target_price: 200 });
  const [loading, setLoading] = useState(false);

  const PRICE_TYPES = ["price_above", "price_below", "percent_change_up", "percent_change_down", "price_range_break"];
  const TECH_TYPES = ["rsi_overbought", "rsi_oversold", "macd_crossover_bullish", "macd_crossover_bearish", "bollinger_break_upper", "bollinger_break_lower", "sma_golden_cross", "sma_death_cross"];
  const VOL_TYPES = ["volume_spike", "volume_dry"];
  const NEWS_TYPES = ["news_high_impact"];

  useEffect(() => {
    if (PRICE_TYPES.includes(alertType)) {
      if (alertType === "price_range_break") setCondition({ lower: 180, upper: 200 });
      else if (alertType.includes("percent")) setCondition({ threshold_percent: 5, timeframe: "1d" });
      else setCondition({ target_price: 200 });
    } else if (TECH_TYPES.includes(alertType)) {
      if (alertType.includes("rsi")) setCondition({ threshold: alertType === "rsi_overbought" ? 70 : 30 });
      else setCondition({});
    } else if (VOL_TYPES.includes(alertType)) {
      setCondition({ threshold_percent: 200 });
    } else {
      setCondition({ min_sentiment_score: 0.7 });
    }
  }, [alertType]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!symbol) return;
    setLoading(true);
    try {
      const result = await api.createAlert({ symbol: symbol.toUpperCase(), alert_type: alertType, condition });
      onCreated(result.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="bg-surface border border-border-subtle rounded-sm p-6 max-w-lg space-y-4">
      <div>
        <label className="label block mb-1.5">Símbolo</label>
        <input
          type="text"
          value={symbol}
          onChange={(e) => setSymbol(e.target.value.toUpperCase())}
          placeholder="AAPL"
          className="w-full bg-navy-lighter border border-border-subtle rounded px-3 py-2 text-sm text-text-primary focus:border-amber focus:outline-none"
        />
      </div>

      <div>
        <label className="label block mb-1.5">Tipo de alerta</label>
        <div className="space-y-2">
          {[
            { label: "Precio", types: PRICE_TYPES },
            { label: "Técnico", types: TECH_TYPES },
            { label: "Volumen", types: VOL_TYPES },
            { label: "Noticias", types: NEWS_TYPES },
          ].map((group) => (
            <div key={group.label}>
              <p className="text-text-muted text-xs mb-1">{group.label}</p>
              <div className="flex flex-wrap gap-1.5">
                {group.types.map((type) => (
                  <button
                    key={type}
                    type="button"
                    onClick={() => setAlertType(type)}
                    className={`px-2.5 py-1 text-xs rounded transition-colors ${
                      alertType === type ? "bg-amber-dim text-amber border border-amber/30" : "bg-navy-lighter text-text-secondary hover:text-text-primary border border-border-subtle"
                    }`}
                  >
                    {ALERT_TYPE_EMOJIS[type]} {ALERT_TYPE_LABELS[type]}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Dynamic condition fields */}
      <div className="space-y-3">
        <label className="label block">Condición</label>
        {Object.entries(condition).map(([key, val]) => (
          <div key={key} className="flex items-center gap-2">
            <span className="text-text-muted text-xs w-32">{key.replace(/_/g, " ")}</span>
            {key === "timeframe" ? (
              <select
                value={val as string}
                onChange={(e) => setCondition((p) => ({ ...p, [key]: e.target.value }))}
                className="flex-1 bg-navy-lighter border border-border-subtle rounded px-3 py-1.5 text-sm text-text-primary focus:border-amber focus:outline-none"
              >
                {["5m", "15m", "1h", "4h", "1d"].map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            ) : (
              <input
                type="number"
                step="any"
                value={val as number}
                onChange={(e) => setCondition((p) => ({ ...p, [key]: parseFloat(e.target.value) }))}
                className="flex-1 bg-navy-lighter border border-border-subtle rounded px-3 py-1.5 text-sm font-mono text-text-primary focus:border-amber focus:outline-none"
              />
            )}
          </div>
        ))}
      </div>

      <button
        type="submit"
        disabled={loading || !symbol}
        className="w-full bg-amber text-navy font-semibold py-2.5 rounded text-sm hover:bg-amber/90 disabled:opacity-50 transition-colors"
      >
        {loading ? "Creando..." : "Crear Alerta"}
      </button>
    </form>
  );
}
