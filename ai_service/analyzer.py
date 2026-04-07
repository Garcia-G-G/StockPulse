"""AI-powered stock analysis using Google Gemini 2.5 Flash via google-genai SDK."""

from google import genai
from google.genai import types
import json
import logging
from models import AnalysisRequest, AnalysisResponse, NewsAnalysisRequest, NewsAnalysisResponse, BriefingRequest, BriefingResponse

logger = logging.getLogger(__name__)


class StockAnalyzer:
    """Generates AI-powered stock analysis via Google Gemini 2.5 Flash."""

    MODEL = "gemini-2.5-flash"

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.client = None
        if api_key:
            self.client = genai.Client(api_key=api_key)

    async def analyze(self, request: AnalysisRequest) -> AnalysisResponse:
        """Analyze stock data and return AI-generated insights."""
        if not self.client:
            return self._fallback_response(request)

        prompt = self._build_prompt(request)

        try:
            response = self.client.models.generate_content(
                model=self.MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.3,
                    max_output_tokens=1024,
                    response_mime_type="application/json",
                ),
            )
            return self._parse_response(request.symbol, response.text)
        except Exception as e:
            logger.error(f"Gemini API error for {request.symbol}: {e}")
            return self._fallback_response(request)

    async def analyze_news(self, request: NewsAnalysisRequest) -> NewsAnalysisResponse:
        """Analyze news impact on a stock."""
        if not self.client:
            return NewsAnalysisResponse(
                symbol=request.symbol,
                impact="unknown",
                summary="AI service unavailable",
                sentiment_score=0.0,
            )

        prompt = f"""Analyze the following news for {request.symbol} and determine its market impact.

News headline: {request.headline}
News summary: {request.content[:500] if request.content else 'Not available'}
Source: {request.source or 'Unknown'}

Respond in JSON format:
- impact: one of "high_positive", "moderate_positive", "low_positive", "neutral", "low_negative", "moderate_negative", "high_negative"
- summary: 1-2 sentence analysis of the news impact
- sentiment_score: float from -1.0 (very bearish) to 1.0 (very bullish)
- key_factors: list of 2-3 key factors

Respond ONLY with valid JSON."""

        try:
            response = self.client.models.generate_content(
                model=self.MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.2,
                    max_output_tokens=512,
                    response_mime_type="application/json",
                ),
            )
            data = json.loads(response.text)
            return NewsAnalysisResponse(
                symbol=request.symbol,
                impact=data.get("impact", "neutral"),
                summary=data.get("summary", "Analysis unavailable"),
                sentiment_score=float(data.get("sentiment_score", 0.0)),
                key_factors=data.get("key_factors", []),
            )
        except Exception as e:
            logger.error(f"News analysis error for {request.symbol}: {e}")
            return NewsAnalysisResponse(
                symbol=request.symbol,
                impact="unknown",
                summary="Analysis failed",
                sentiment_score=0.0,
            )

    async def daily_briefing(self, request: BriefingRequest) -> BriefingResponse:
        """Generate a daily market briefing for the user's watchlist."""
        if not self.client:
            return self._fallback_briefing(request)

        watchlist_summary = json.dumps(request.watchlist_data, indent=2)

        prompt = f"""Generate a concise daily market briefing for a trader monitoring these stocks.

Watchlist data:
{watchlist_summary}

Write the briefing in Spanish. Structure:
1. "Resumen General" — 2-3 sentences on overall market sentiment
2. "Movimientos Destacados" — top 3 movers with brief analysis
3. "Señales Técnicas" — any notable technical signals (RSI extremes, MACD crossovers, etc.)
4. "Vigilar Hoy" — 2-3 things to watch during the trading day

Respond in JSON format:
- title: briefing title with date
- sections: list of objects with "heading" and "content" fields
- overall_sentiment: "bullish", "bearish", or "neutral"

Keep it data-dense and actionable. No fluff. Respond ONLY with valid JSON."""

        try:
            response = self.client.models.generate_content(
                model=self.MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.4,
                    max_output_tokens=2048,
                    response_mime_type="application/json",
                ),
            )
            data = json.loads(response.text)
            return BriefingResponse(
                title=data.get("title", "Briefing del Día"),
                sections=data.get("sections", []),
                overall_sentiment=data.get("overall_sentiment", "neutral"),
            )
        except Exception as e:
            logger.error(f"Briefing generation error: {e}")
            return self._fallback_briefing(request)

    def _build_prompt(self, request: AnalysisRequest) -> str:
        price_info = json.dumps(request.price_data, indent=2)
        tech_info = json.dumps(request.technical_data, indent=2) if request.technical_data else "Not available"
        news_info = json.dumps(request.news_data, indent=2) if request.news_data else "Not available"

        return f"""Analyze the following stock data for {request.symbol} and provide a brief investment analysis.

Price Data:
{price_info}

Technical Indicators:
{tech_info}

Recent News:
{news_info}

Respond in JSON format with these exact fields:
- summary: 2-3 sentence analysis (in Spanish)
- sentiment: one of "bullish", "bearish", or "neutral"
- recommendation: one of "watch", "consider_buy", "consider_sell", "hold"
- confidence: number from 0 to 100
- key_factors: list of 3-5 key factors driving the analysis
- risk_level: one of "low", "medium", "high"
- details: object with key observations

IMPORTANT: This is for informational purposes only, not financial advice.
Respond ONLY with valid JSON."""

    def _parse_response(self, symbol: str, text: str) -> AnalysisResponse:
        try:
            data = json.loads(text)
            return AnalysisResponse(
                symbol=symbol,
                summary=data.get("summary", "Analysis unavailable"),
                sentiment=data.get("sentiment", "neutral"),
                recommendation=data.get("recommendation", "watch"),
                confidence=float(data.get("confidence", 50)),
                key_factors=data.get("key_factors", []),
                risk_level=data.get("risk_level", "medium"),
                details=data.get("details", {}),
            )
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            logger.warning(f"Failed to parse Gemini response for {symbol}: {e}")
            return AnalysisResponse(
                symbol=symbol,
                summary=text[:500] if text else "Analysis unavailable",
                sentiment="neutral",
                recommendation="watch",
                confidence=30.0,
                details={"raw_response": text[:1000] if text else ""},
            )

    def _fallback_response(self, request: AnalysisRequest) -> AnalysisResponse:
        price = request.price_data.get("c", 0)
        change = request.price_data.get("dp", 0)
        sentiment = "bullish" if change > 0 else "bearish" if change < 0 else "neutral"

        return AnalysisResponse(
            symbol=request.symbol,
            summary=f"{request.symbol} está en ${price} con un cambio de {change}%. Análisis AI no disponible.",
            sentiment=sentiment,
            recommendation="watch",
            confidence=20.0,
            details={"note": "AI service unavailable, basic data only"},
        )

    def _fallback_briefing(self, request: BriefingRequest) -> BriefingResponse:
        sections = []
        for item in request.watchlist_data[:5]:
            symbol = item.get("symbol", "???")
            price = item.get("price", 0)
            change = item.get("change_percent", 0)
            sections.append({
                "heading": symbol,
                "content": f"Precio: ${price} | Cambio: {change}%",
            })

        return BriefingResponse(
            title="Briefing del Día (sin AI)",
            sections=sections,
            overall_sentiment="neutral",
        )
