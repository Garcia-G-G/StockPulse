const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000/api/v1";

export interface Quote {
  c: number; d: number; dp: number; h: number; l: number; o: number; pc: number; t: number;
}

export interface WatchlistItem {
  id: string;
  type: string;
  attributes: {
    symbol: string;
    company_name: string;
    exchange: string;
    asset_type: string;
    priority: number;
    is_active: boolean;
    created_at: string;
  };
}

export interface Alert {
  id: string;
  type: string;
  attributes: {
    symbol: string;
    alert_type: string;
    condition: Record<string, unknown>;
    notification_channels: string[];
    cooldown_minutes: number;
    is_enabled: boolean;
    is_one_time: boolean;
    last_triggered_at: string | null;
    trigger_count: number;
    max_triggers: number | null;
    ai_analysis_enabled: boolean;
    notes: string | null;
    created_at: string;
  };
}

export interface AlertHistory {
  id: string;
  attributes: {
    symbol: string;
    alert_type: string;
    triggered_at: string;
    price_at_trigger: number;
    change_percent: number | null;
    ai_analysis: string | null;
    ai_importance_score: number | null;
  };
}

export interface HealthStatus {
  status: string;
  timestamp: string;
  database: boolean;
  redis: boolean;
  sidekiq: boolean;
}

export interface PriceUpdate {
  symbol: string;
  price: number;
  open: number | null;
  change: number | null;
  change_percent: number | null;
  high: number | null;
  low: number | null;
  volume: number;
  vwap: number | null;
  timestamp: string;
  source: string;
}

class ApiClient {
  private baseUrl: string;
  private headers: Record<string, string>;

  constructor() {
    this.baseUrl = API_URL;
    this.headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      ...options,
      headers: { ...this.headers, ...options.headers },
    });
    if (!res.ok) {
      const error = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(error.error || `API Error: ${res.status}`);
    }
    return res.json();
  }

  // Health
  async getHealth(): Promise<HealthStatus> {
    return this.request("/health");
  }

  // Watchlist
  async getWatchlist(): Promise<{ data: WatchlistItem[] }> {
    return this.request("/watchlists");
  }

  async addToWatchlist(symbol: string, companyName: string, exchange: string = "NASDAQ"): Promise<{ data: WatchlistItem }> {
    return this.request("/watchlists", {
      method: "POST",
      body: JSON.stringify({ watchlist_item: { symbol, company_name: companyName, exchange } }),
    });
  }

  async removeFromWatchlist(id: string): Promise<void> {
    await this.request(`/watchlists/${id}`, { method: "DELETE" });
  }

  async getQuote(id: string): Promise<Quote> {
    return this.request(`/watchlists/${id}/quote`);
  }

  // Alerts
  async getAlerts(): Promise<{ data: Alert[] }> {
    return this.request("/alerts");
  }

  async createAlert(data: { symbol: string; alert_type: string; condition: Record<string, unknown>; cooldown_minutes?: number; notification_channels?: string[] }): Promise<{ data: Alert }> {
    return this.request("/alerts", {
      method: "POST",
      body: JSON.stringify({ alert: data }),
    });
  }

  async updateAlert(id: string, data: Partial<Alert["attributes"]>): Promise<{ data: Alert }> {
    return this.request(`/alerts/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ alert: data }),
    });
  }

  async deleteAlert(id: string): Promise<void> {
    await this.request(`/alerts/${id}`, { method: "DELETE" });
  }

  async getAlertHistory(): Promise<{ data: AlertHistory[] }> {
    return this.request("/alerts/history");
  }

  // Analysis
  async getAnalysisOverview(symbol: string) {
    return this.request(`/analysis/overview?symbol=${symbol}`);
  }

  async getAnalysisTechnical(symbol: string) {
    return this.request(`/analysis/technical?symbol=${symbol}`);
  }

  async getAnalysisNews(symbol: string) {
    return this.request(`/analysis/news?symbol=${symbol}`);
  }

  async getBriefing() {
    return this.request("/analysis/briefing");
  }

  // Settings
  async getSettings() {
    return this.request("/settings");
  }

  async updateSettings(data: Record<string, unknown>) {
    return this.request("/settings", {
      method: "PATCH",
      body: JSON.stringify({ user: data }),
    });
  }

  async testNotification() {
    return this.request("/settings/test_notification", { method: "POST" });
  }

  async mute(minutes: number) {
    return this.request("/settings/mute", {
      method: "POST",
      body: JSON.stringify({ minutes }),
    });
  }

  async unmute() {
    return this.request("/settings/unmute", { method: "POST" });
  }
}

export const api = new ApiClient();
