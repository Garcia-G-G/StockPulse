"""Rule-based fallback analyzer when Gemini is unavailable or rate-limited."""

from datetime import datetime

from models import (
    BriefingRequest,
    BriefingResponse,
    ImportanceEvaluationRequest,
    ImportanceEvaluationResponse,
    NewsAnalysisRequest,
    NewsAnalysisResponse,
    PriceAnalysisRequest,
    PriceAnalysisResponse,
)

POSITIVE_KEYWORDS = {"surge", "rally", "beat", "record", "upgrade", "growth", "profit", "gain", "positive", "strong"}
NEGATIVE_KEYWORDS = {"crash", "fall", "miss", "downgrade", "loss", "decline", "warning", "risk", "weak", "layoff"}
HIGH_REP_SOURCES = {"bloomberg", "reuters", "wsj", "financial times", "cnbc", "barron's"}

DISCLAIMER = "Esto no es asesoramiento financiero. Análisis generado por reglas automáticas (IA no disponible)."


class FallbackAnalyzer:
    """Rule-based analysis as fallback when Gemini is unavailable."""

    async def analyze_price(self, request: PriceAnalysisRequest) -> PriceAnalysisResponse:
        pct = request.change_percent
        factors = []
        risks = []

        if abs(pct) > 3:
            sentiment = "bullish" if pct > 0 else "bearish"
            confidence = 60
            factors.append(f"Movimiento significativo de {pct:+.2f}%")
        else:
            sentiment = "neutral"
            confidence = 40

        if request.indicators:
            rsi = request.indicators.get("rsi")
            if rsi is not None:
                rsi = float(rsi)
                if rsi > 70:
                    factors.append(f"RSI en zona de sobrecompra ({rsi:.1f})")
                    risks.append("Posible corrección por sobrecompra")
                elif rsi < 30:
                    factors.append(f"RSI en zona de sobreventa ({rsi:.1f})")
                    factors.append("Posible rebote técnico")

        if request.volume and request.volume > 0:
            factors.append(f"Volumen: {request.volume:,}")

        summary = (
            f"{request.symbol} muestra un cambio de {pct:+.2f}% "
            f"con precio actual de ${request.current_price:.2f}. {DISCLAIMER}"
        )

        return PriceAnalysisResponse(
            summary=summary,
            sentiment=sentiment,
            confidence=confidence,
            key_factors=factors[:5],
            risks=risks[:5],
            timeframe="short",
        )

    async def analyze_news(self, request: NewsAnalysisRequest) -> NewsAnalysisResponse:
        text = f"{request.headline} {request.summary}".lower()

        pos_count = sum(1 for w in POSITIVE_KEYWORDS if w in text)
        neg_count = sum(1 for w in NEGATIVE_KEYWORDS if w in text)

        if pos_count > neg_count:
            direction = "positive"
        elif neg_count > pos_count:
            direction = "negative"
        else:
            direction = "neutral"

        source_lower = request.source.lower()
        impact = "high" if any(s in source_lower for s in HIGH_REP_SOURCES) else "medium"

        return NewsAnalysisResponse(
            impact_level=impact,
            direction=direction,
            timeframe="short_term",
            explanation=(
                f"Noticia de {request.source} sobre {request.symbol}. "
                f"Palabras clave: {pos_count} positivas, {neg_count} negativas. {DISCLAIMER}"
            ),
            affected_metrics=["precio", "sentimiento"],
        )

    async def generate_briefing(self, request: BriefingRequest) -> BriefingResponse:
        insights = {}
        movers = []

        for item in request.watchlist:
            symbol = item.get("symbol", "?")
            price = item.get("price", 0)
            change = item.get("change_percent", 0)
            direction = "sube" if change > 0 else "baja" if change < 0 else "sin cambio"
            insights[symbol] = f"${price:.2f} ({change:+.2f}%) — {direction}"
            if abs(change) > 2:
                movers.append(symbol)

        return BriefingResponse(
            market_summary=(
                f"Resumen del mercado para {len(request.watchlist)} valores monitoreados. "
                f"Valores con movimiento significativo: {', '.join(movers) if movers else 'ninguno'}. {DISCLAIMER}"
            ),
            per_symbol_insights=insights,
            symbols_to_watch=movers[:5],
            market_events=[],
            generated_at=datetime.utcnow(),
        )

    async def evaluate_importance(self, request: ImportanceEvaluationRequest) -> ImportanceEvaluationResponse:
        context = request.current_context or {}
        change = abs(float(context.get("change_percent", 0)))

        if "price" in request.alert_type:
            score = 80 if change > 5 else 60 if change > 2 else 40
        elif "technical" in request.alert_type:
            score = 60
        elif "news" in request.alert_type:
            score = 50
        else:
            score = 40

        return ImportanceEvaluationResponse(
            importance_score=score,
            should_notify=score >= 50,
            reasoning=(
                f"Alerta {request.alert_type} para {request.symbol}: "
                f"puntuación {score}/100 basada en reglas automáticas. {DISCLAIMER}"
            ),
            suggested_action="Revisar manualmente" if score >= 70 else None,
        )
