"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Bell, BellOff, Send, MessageSquare, Mail, Clock } from "lucide-react";

export default function SettingsPage() {
  const [settings, setSettings] = useState<Record<string, unknown> | null>(null);
  const [muted, setMuted] = useState(false);
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    api.getSettings().then((r) => {
      setSettings(r as Record<string, unknown>);
      setMuted(!!(r as Record<string, unknown>).muted);
    }).catch(() => {});
  }, []);

  const handleMute = async () => {
    if (muted) {
      await api.unmute();
      setMuted(false);
    } else {
      await api.mute(60);
      setMuted(true);
    }
  };

  const handleTestNotification = async () => {
    setTesting(true);
    try {
      await api.testNotification();
    } finally {
      setTesting(false);
    }
  };

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="font-[family-name:var(--font-display)] text-3xl font-bold">Configuración</h1>
        <p className="text-text-muted text-sm mt-1">Preferencias de notificaciones y cuenta</p>
      </div>

      {/* Notification Channels */}
      <div className="bg-surface border border-border-subtle rounded-sm p-5 space-y-4">
        <p className="label">Canales de notificación</p>
        {[
          { icon: Send, label: "Telegram", desc: "Mensajes directos al bot" },
          { icon: MessageSquare, label: "WhatsApp", desc: "Via OpenClaw / Twilio" },
          { icon: Mail, label: "Email", desc: "Alertas por correo" },
        ].map((ch) => (
          <div key={ch.label} className="flex items-center justify-between py-2">
            <div className="flex items-center gap-3">
              <ch.icon className="w-5 h-5 text-text-muted" />
              <div>
                <p className="text-sm font-medium">{ch.label}</p>
                <p className="text-text-muted text-xs">{ch.desc}</p>
              </div>
            </div>
            <div className="w-10 h-5 rounded-full bg-bull/20 relative cursor-pointer">
              <div className="w-4 h-4 rounded-full bg-bull absolute top-0.5 right-0.5" />
            </div>
          </div>
        ))}
      </div>

      {/* Mute */}
      <div className="bg-surface border border-border-subtle rounded-sm p-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            {muted ? <BellOff className="w-5 h-5 text-bear" /> : <Bell className="w-5 h-5 text-bull" />}
            <div>
              <p className="text-sm font-medium">{muted ? "Notificaciones silenciadas" : "Notificaciones activas"}</p>
              <p className="text-text-muted text-xs">{muted ? "Silenciado por 1 hora" : "Recibes alertas en tiempo real"}</p>
            </div>
          </div>
          <button
            onClick={handleMute}
            className={`px-4 py-2 text-sm rounded font-medium transition-colors ${
              muted ? "bg-bull-dim text-bull hover:bg-bull/20" : "bg-bear-dim text-bear hover:bg-bear/20"
            }`}
          >
            {muted ? "Activar" : "Silenciar 1h"}
          </button>
        </div>
      </div>

      {/* Test */}
      <div className="bg-surface border border-border-subtle rounded-sm p-5">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium">Notificación de prueba</p>
            <p className="text-text-muted text-xs">Envía una notificación de prueba a todos los canales</p>
          </div>
          <button
            onClick={handleTestNotification}
            disabled={testing}
            className="px-4 py-2 text-sm bg-amber text-navy rounded font-medium hover:bg-amber/90 disabled:opacity-50"
          >
            {testing ? "Enviando..." : "Enviar prueba"}
          </button>
        </div>
      </div>

      {/* Timezone */}
      <div className="bg-surface border border-border-subtle rounded-sm p-5">
        <div className="flex items-center gap-3 mb-3">
          <Clock className="w-5 h-5 text-text-muted" />
          <p className="label">Zona horaria</p>
        </div>
        <select className="bg-navy-lighter border border-border-subtle rounded px-3 py-2 text-sm text-text-primary focus:border-amber focus:outline-none w-full">
          <option value="US/Eastern">US/Eastern (ET)</option>
          <option value="US/Central">US/Central (CT)</option>
          <option value="US/Pacific">US/Pacific (PT)</option>
          <option value="America/Mexico_City">America/Mexico_City</option>
        </select>
      </div>
    </div>
  );
}
