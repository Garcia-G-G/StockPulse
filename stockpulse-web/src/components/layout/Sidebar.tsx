"use client";
import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, List, Bell, BarChart3, FileText, Settings, ChevronLeft, ChevronRight, Activity } from "lucide-react";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/watchlist", label: "Watchlist", icon: List },
  { href: "/alerts", label: "Alertas", icon: Bell },
  { href: "/analysis", label: "Análisis", icon: BarChart3 },
  { href: "/briefing", label: "Briefing", icon: FileText },
  { href: "/settings", label: "Config", icon: Settings },
];

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const pathname = usePathname();

  return (
    <aside className={`${collapsed ? "w-16" : "w-56"} flex-shrink-0 bg-navy-light border-r border-border-subtle flex flex-col transition-all duration-200 hidden md:flex`}>
      <div className="h-14 flex items-center px-4 border-b border-border-subtle">
        {!collapsed && (
          <span className="font-[family-name:var(--font-display)] text-lg font-bold tracking-tight text-amber">
            Stock<span className="text-text-primary">Pulse</span>
          </span>
        )}
        {collapsed && <Activity className="w-5 h-5 text-amber mx-auto" />}
      </div>

      <nav className="flex-1 py-3 space-y-0.5">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname === item.href || (item.href !== "/" && pathname.startsWith(item.href));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-4 py-2.5 text-sm transition-colors relative ${
                isActive
                  ? "text-amber bg-amber-dim"
                  : "text-text-secondary hover:text-text-primary hover:bg-surface-hover"
              }`}
            >
              {isActive && <div className="absolute left-0 top-1 bottom-1 w-0.5 bg-amber rounded-r" />}
              <item.icon className="w-4.5 h-4.5 flex-shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          );
        })}
      </nav>

      <button
        onClick={() => setCollapsed(!collapsed)}
        className="p-3 border-t border-border-subtle text-text-muted hover:text-text-secondary transition-colors"
      >
        {collapsed ? <ChevronRight className="w-4 h-4 mx-auto" /> : <ChevronLeft className="w-4 h-4" />}
      </button>
    </aside>
  );
}
