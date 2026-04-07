"""Pydantic models for AI service request/response."""

import re
from pydantic import BaseModel, Field, field_validator
from typing import Any, Literal, Optional


# ---------------------------------------------------------------------------
# Shared constants
# ---------------------------------------------------------------------------
VALID_SYMBOL_RE = re.compile(r"^[A-Z]{1,5}$")  # US stock tickers
MAX_WATCHLIST_SIZE = 50
MAX_HEADLINE_LEN = 500
MAX_CONTENT_LEN = 2000


# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------

class AnalysisRequest(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=5, examples=["AAPL"])
    price_data: dict[str, Any]
    technical_data: Optional[dict[str, Any]] = None
    news_data: Optional[dict[str, Any]] = None

    @field_validator("symbol")
    @classmethod
    def validate_symbol(cls, v: str) -> str:
        v = v.upper().strip()
        if not VALID_SYMBOL_RE.match(v):
            raise ValueError(
                "symbol must be 1-5 uppercase ASCII letters (e.g. AAPL)"
            )
        return v


class NewsAnalysisRequest(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=5)
    headline: str = Field(..., min_length=1, max_length=MAX_HEADLINE_LEN)
    content: Optional[str] = Field(None, max_length=MAX_CONTENT_LEN)
    source: Optional[str] = Field(None, max_length=200)

    @field_validator("symbol")
    @classmethod
    def validate_symbol(cls, v: str) -> str:
        v = v.upper().strip()
        if not VALID_SYMBOL_RE.match(v):
            raise ValueError(
                "symbol must be 1-5 uppercase ASCII letters (e.g. AAPL)"
            )
        return v


class BriefingRequest(BaseModel):
    watchlist_data: list[dict[str, Any]] = Field(
        ..., min_length=1, max_length=MAX_WATCHLIST_SIZE
    )
    user_timezone: str = "US/Eastern"

    @field_validator("user_timezone")
    @classmethod
    def validate_timezone(cls, v: str) -> str:
        # Allow only reasonable timezone strings — prevent injection via tz field
        if len(v) > 50 or not re.match(r"^[A-Za-z_/]+$", v):
            raise ValueError("Invalid timezone format")
        return v


# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------

class AnalysisResponse(BaseModel):
    symbol: str
    summary: str
    sentiment: Literal["bullish", "bearish", "neutral"] = "neutral"
    recommendation: Literal[
        "watch", "consider_buy", "consider_sell", "hold"
    ] = "watch"
    confidence: float = Field(default=50.0, ge=0.0, le=100.0)
    key_factors: list[str] = Field(default_factory=list)
    risk_level: Literal["low", "medium", "high"] = "medium"
    details: dict[str, Any] = Field(default_factory=dict)


class NewsAnalysisResponse(BaseModel):
    symbol: str
    impact: Literal[
        "high_positive", "moderate_positive", "low_positive",
        "neutral",
        "low_negative", "moderate_negative", "high_negative",
        "unknown",
    ] = "neutral"
    summary: str
    sentiment_score: float = Field(default=0.0, ge=-1.0, le=1.0)
    key_factors: list[str] = Field(default_factory=list)


class BriefingResponse(BaseModel):
    title: str
    sections: list[dict[str, Any]] = Field(default_factory=list)
    overall_sentiment: Literal["bullish", "bearish", "neutral"] = "neutral"


class HealthResponse(BaseModel):
    status: str
    service: str
    model: str = "gemini-2.5-flash"
    version: str = "2.0.0"
