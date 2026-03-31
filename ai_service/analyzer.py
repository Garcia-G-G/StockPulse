"""AI-powered stock analysis using Google Gemini."""

from models import AnalysisRequest, AnalysisResponse


class StockAnalyzer:
    """Generates AI-powered stock analysis via Google Gemini."""

    def __init__(self, api_key: str):
        self.api_key = api_key

    async def analyze(self, request: AnalysisRequest) -> AnalysisResponse:
        """Analyze stock data and return AI-generated insights."""
        raise NotImplementedError("StockAnalyzer.analyze not yet implemented")
