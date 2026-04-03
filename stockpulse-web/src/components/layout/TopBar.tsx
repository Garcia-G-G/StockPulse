"use client";
import { useEffect, useState } from "react";
import { Wifi, WifiOff, Clock } from "lucide-react";
import { useStore } from "@/lib/store";

export function TopBar() {
  const connected = useStore((s) => s.connected);
  const [time, setTime] = useState("");
  const [marketOpen, setMarketOpen] = useState(false);

  useEffect(() => {
    const tick = () => {
      const now = new Date();
      const et = new Intl.DateTimeFormat("es", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        timeZone: "America/New_York",
        hour12: false,
      }).format(now);
      setTime(et);

      const etHour = parseInt(new Intl.DateTimeFormat("en", { hour: "2-digit", hour12: false, timeZone: "America/New_York" }).format(now));
      const etMin = parseInt(new Intl.DateTimeFormat("en", { minute: "2-digit", timeZone: "America/New_York" }).format(now));
      const day = new Date(now.toLocaleString("en", { timeZone: "America/New_York" })).getDay();
      const totalMin = etHour * 60 + etMin;
      setMarketOpen(day >= 1 && day <= 5 && totalMin >= 570 && totalMin < 960);
    };
    tick();
    const interval = setInterval(tick, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header className="h-14 border-b border-border-subtle bg-navy-light/80 backdrop-blur-sm flex items-center justify-between px-6 flex-shrink-0">
      <div className="flex items-center gap-4">
        <div className="md:hidden font-[family-name:var(--font-display)] text-lg font-bold text-amber">
          SP
        </div>
        <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded text-xs font-medium ${
          marketOpen ? "bg-bull-dim text-bull" : "bg-bear-dim text-bear"
        }`}>
          <span className={`w-1.5 h-1.5 rounded-full ${marketOpen ? "bg-bull animate-pulse-dot" : "bg-bear"}`} />
          {marketOpen ? "Mercado Abierto" : "Mercado Cerrado"}
        </div>
      </div>

      <div className="flex items-center gap-5">
        <div className="flex items-center gap-1.5 text-text-muted text-xs font-mono">
          <Clock className="w-3.5 h-3.5" />
          <span>{time} ET</span>
        </div>
        <div className={`flex items-center gap-1.5 text-xs ${connected ? "text-bull" : "text-bear"}`}>
          {connected ? <Wifi className="w-3.5 h-3.5" /> : <WifiOff className="w-3.5 h-3.5" />}
          <span className="hidden sm:inline">{connected ? "Conectado" : "Desconectado"}</span>
        </div>
      </div>
    </header>
  );
}
