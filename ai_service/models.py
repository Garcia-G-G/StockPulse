"""Pydantic v2 request/response models for the StockPulse AI service."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


# --- Enums ---


class SentimentType(str, Enum):
    bullish = "bullish"
    bearish = "bearish"
    neutral = "neutral"


class ImpactLevel(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class Direction(str, Enum):
    positive = "positive"
    negative = "negative"
    neutral = "neutral"


# --- Request Models ---


class PriceAnalysisRequest(BaseModel):
    model_config = ConfigDict(strict=False)

    symbol: str = Field(..., min_length=1, max_length=5)
    current_price: float = Field(..., gt=0)
    previous_close: float = Field(..., gt=0)
    change_percent: float
    volume: Optional[int] = None
    market_cap: Optional[float] = None
    pe_ratio: Optional[float] = None
    indicators: Optional[dict] = None
    company_profile: Optional[dict] = None
    recent_news: Optional[list[str]] = None
    watchlist_context: Optional[str] = None

    @field_validator("symbol")
    @classmethod
    def uppercase_symbol(cls, v: str) -> str:
        return v.upper().strip()


class NewsAnalysisRequest(BaseModel):
    model_config = ConfigDict(strict=False)

    symbol: str = Field(..., min_length=1, max_length=10)
    headline: str = Field(..., min_length=5, max_length=500)
    summary: str = Field(..., min_length=10, max_length=2000)
    source: str
    sentiment: Optional[str] = None
    published_at: Optional[datetime] = None


class BriefingRequest(BaseModel):
    model_config = ConfigDict(strict=False)

    watchlist: list[dict]
    include_technicals: bool = True
    include_macro: bool = True


class ImportanceEvaluationRequest(BaseModel):
    model_config = ConfigDict(strict=False)

    alert_type: str = Field(..., pattern=r"^(price|technical|news|volume)")
    symbol: str
    alert_description: str
    current_context: Optional[dict] = None


# --- Response Models ---


class PriceAnalysisResponse(BaseModel):
    model_config = ConfigDict(strict=False)

    summary: str
    sentiment: SentimentType
    confidence: int = Field(..., ge=0, le=100)
    key_factors: list[str] = Field(default_factory=list, max_length=5)
    risks: list[str] = Field(default_factory=list, max_length=5)
    timeframe: str = "short"
    cached: bool = False


class NewsAnalysisResponse(BaseModel):
    model_config = ConfigDict(strict=False)

    impact_level: ImpactLevel
    direction: Direction
    timeframe: str = "short_term"
    explanation: str
    affected_metrics: list[str] = Field(default_factory=list)
    cached: bool = False


class BriefingResponse(BaseModel):
    model_config = ConfigDict(strict=False)

    market_summary: str
    per_symbol_insights: dict[str, str] = Field(default_factory=dict)
    symbols_to_watch: list[str] = Field(default_factory=list)
    market_events: list[str] = Field(default_factory=list)
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    cached: bool = False


class ImportanceEvaluationResponse(BaseModel):
    model_config = ConfigDict(strict=False)

    importance_score: int = Field(..., ge=0, le=100)
    should_notify: bool
    reasoning: str
    suggested_action: Optional[str] = None
    cached: bool = False


class HealthResponse(BaseModel):
    status: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    services: dict[str, bool] = Field(default_factory=dict)


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
