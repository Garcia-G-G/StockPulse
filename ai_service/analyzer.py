"""GeminiAnalyzer — AI-powered stock analysis using Google Gemini via google-genai SDK."""

from __future__ import annotations

import json
import logging
import os
import re

from google import genai
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

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

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "Eres un analista financiero experto. Proporcionas análisis técnico y fundamental de acciones.\n"
    "Responde siempre en español.\n"
    "Nunca des recomendaciones de compra/venta. Solo análisis objetivo.\n"
    "Sé conciso: máximo 3-4 oraciones por análisis.\n"
    "Incluye disclaimer: 'Esto no es asesoramiento financiero.'\n"
    "Devuelve tu respuesta como JSON válido sin bloques de código markdown."
)


class GeminiAnalyzer:
    """Generates AI-powered stock analysis via Google Gemini (gemini-2.5-flash)."""

    def __init__(self):
        api_key = os.getenv("GOOGLE_AI_API_KEY", "")
        self.client = genai.Client(api_key=api_key) if api_key else None
        self.model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        retry=retry_if_exception_type(Exception),
        reraise=True,
    )
    def _generate(self, prompt: str) -> str:
        if not self.client:
            raise RuntimeError("Gemini client not initialized (missing API key)")

        response = self.client.models.generate_content(
            model=self.model,
            contents=f"{SYSTEM_PROMPT}\n\n{prompt}",
        )
        return response.text

    async def analyze_price(self, request: PriceAnalysisRequest) -> PriceAnalysisResponse:
        prompt = self._build_price_prompt(request)
        raw = self._generate(prompt)
        data = _extract_json(raw)

        if data is None:
            raw = self._generate(prompt + "\n\nIMPORTANTE: Devuelve SOLO JSON válido, sin texto adicional.")
            data = _extract_json(raw)

        if data is None:
            raise ValueError("Gemini returned unparseable response")

        return PriceAnalysisResponse(
            summary=data.get("summary", data.get("resumen", "")),
            sentiment=data.get("sentiment", data.get("sentimiento", "neutral")),
            confidence=int(data.get("confidence", data.get("confianza", 50))),
            key_factors=data.get("key_factors", data.get("factores_clave", []))[:5],
            risks=data.get("risks", data.get("riesgos", []))[:5],
            timeframe=data.get("timeframe", data.get("horizonte", "short")),
        )

    async def analyze_news(self, request: NewsAnalysisRequest) -> NewsAnalysisResponse:
        prompt = self._build_news_prompt(request)
        raw = self._generate(prompt)
        data = _extract_json(raw)

        if data is None:
            raise ValueError("Gemini returned unparseable response for news analysis")

        return NewsAnalysisResponse(
            impact_level=data.get("impact_level", data.get("nivel_impacto", "medium")),
            direction=data.get("direction", data.get("direccion", "neutral")),
            timeframe=data.get("timeframe", data.get("horizonte", "short_term")),
            explanation=data.get("explanation", data.get("explicacion", "")),
            affected_metrics=data.get("affected_metrics", data.get("metricas_afectadas", [])),
        )

    async def generate_briefing(self, request: BriefingRequest) -> BriefingResponse:
        prompt = self._build_briefing_prompt(request)
        raw = self._generate(prompt)
        data = _extract_json(raw)

        if data is None:
            raise ValueError("Gemini returned unparseable response for briefing")

        return BriefingResponse(
            market_summary=data.get("market_summary", data.get("resumen_mercado", "")),
            per_symbol_insights=data.get("per_symbol_insights", data.get("insights_por_simbolo", {})),
            symbols_to_watch=data.get("symbols_to_watch", data.get("simbolos_a_vigilar", [])),
            market_events=data.get("market_events", data.get("eventos_mercado", [])),
        )

    async def evaluate_importance(self, request: ImportanceEvaluationRequest) -> ImportanceEvaluationResponse:
        prompt = self._build_importance_prompt(request)
        raw = self._generate(prompt)
        data = _extract_json(raw)

        if data is None:
            raise ValueError("Gemini returned unparseable response for importance evaluation")

        return ImportanceEvaluationResponse(
            importance_score=int(data.get("importance_score", data.get("puntuacion_importancia", 50))),
            should_notify=data.get("should_notify", data.get("notificar", True)),
            reasoning=data.get("reasoning", data.get("razonamiento", "")),
            suggested_action=data.get("suggested_action", data.get("accion_sugerida")),
        )

    # --- Prompt Builders ---

    def _build_price_prompt(self, r: PriceAnalysisRequest) -> str:
        parts = [
            f"Analiza la acción {r.symbol}.",
            f"Precio actual: ${r.current_price:.2f}",
            f"Cierre anterior: ${r.previous_close:.2f}",
            f"Cambio: {r.change_percent:+.2f}%",
        ]
        if r.volume:
            parts.append(f"Volumen: {r.volume:,}")
        if r.indicators:
            parts.append(f"Indicadores técnicos: {json.dumps(r.indicators)}")
        if r.company_profile:
            parts.append(f"Perfil de empresa: {json.dumps(r.company_profile)}")
        if r.recent_news:
            parts.append(f"Noticias recientes: {'; '.join(r.recent_news[:5])}")
        parts.append(
            '\nDevuelve JSON con: {"summary": "...", "sentiment": "bullish|bearish|neutral", '
            '"confidence": 0-100, "key_factors": ["..."], "risks": ["..."], "timeframe": "short|medium|long"}'
        )
        return "\n".join(parts)

    def _build_news_prompt(self, r: NewsAnalysisRequest) -> str:
        parts = [
            f"Analiza esta noticia sobre {r.symbol}:",
            f"Titular: {r.headline}",
            f"Resumen: {r.summary}",
            f"Fuente: {r.source}",
        ]
        if r.sentiment:
            parts.append(f"Sentimiento previo: {r.sentiment}")
        parts.append(
            '\nDevuelve JSON con: {"impact_level": "high|medium|low", "direction": "positive|negative|neutral", '
            '"timeframe": "immediate|short_term|medium_term", "explanation": "...", "affected_metrics": ["..."]}'
        )
        return "\n".join(parts)

    def _build_briefing_prompt(self, r: BriefingRequest) -> str:
        symbols_info = []
        for item in r.watchlist[:20]:
            s = item.get("symbol", "?")
            p = item.get("price", 0)
            c = item.get("change_percent", 0)
            symbols_info.append(f"  {s}: ${p:.2f} ({c:+.2f}%)")

        parts = [
            "Genera un briefing matutino del mercado para este watchlist:",
            "\n".join(symbols_info),
        ]
        if r.include_technicals:
            parts.append("Incluye análisis técnico breve.")
        if r.include_macro:
            parts.append("Incluye contexto macroeconómico.")
        parts.append(
            '\nDevuelve JSON con: {"market_summary": "...", "per_symbol_insights": {"AAPL": "...", ...}, '
            '"symbols_to_watch": ["..."], "market_events": ["..."]}'
        )
        return "\n".join(parts)

    def _build_importance_prompt(self, r: ImportanceEvaluationRequest) -> str:
        parts = [
            f"Evalúa la importancia de esta alerta para decidir si notificar al usuario:",
            f"Tipo: {r.alert_type}",
            f"Símbolo: {r.symbol}",
            f"Descripción: {r.alert_description}",
        ]
        if r.current_context:
            parts.append(f"Contexto actual: {json.dumps(r.current_context)}")
        parts.append(
            '\nDevuelve JSON con: {"importance_score": 0-100, "should_notify": true|false, '
            '"reasoning": "...", "suggested_action": "..."}'
        )
        return "\n".join(parts)


def _extract_json(text: str) -> dict | None:
    """Extract JSON from Gemini response, handling markdown code blocks."""
    if not text:
        return None

    # Try direct parse
    try:
        return json.loads(text)
    except (json.JSONDecodeError, TypeError):
        pass

    # Try extracting from ```json ... ``` blocks
    match = re.search(r"```(?:json)?\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except (json.JSONDecodeError, TypeError):
            pass

    # Try finding first { and last }
    first_brace = text.find("{")
    last_brace = text.rfind("}")
    if first_brace != -1 and last_brace > first_brace:
        try:
            return json.loads(text[first_brace : last_brace + 1])
        except (json.JSONDecodeError, TypeError):
            pass

    return None
