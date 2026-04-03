"use client";
import { useStore } from "@/lib/store";

export function ConnectionStatus() {
  const connected = useStore((s) => s.connected);
  return (
    <div className="flex items-center gap-1.5 text-xs">
      <span className={`w-2 h-2 rounded-full ${connected ? "bg-bull animate-pulse-dot" : "bg-bear"}`} />
      <span className={connected ? "text-bull" : "text-bear"}>
        {connected ? "En vivo" : "Sin conexión"}
      </span>
    </div>
  );
}
