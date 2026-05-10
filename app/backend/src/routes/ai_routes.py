from fastapi import APIRouter, Depends
from app.schemas.index import AIAnalysisRequest, AIAnalysisResponse
from app.services.ai_service import AIService

router = APIRouter()
ai_service = AIService()

@router.post("/analyze-text", response_model=AIAnalysisResponse)
async def analyze_text(request: AIAnalysisRequest):
    # TODO: Auth layer check JWT -> Lấy user_vibe từ database
    # Mock data cho user preferences
    user_vibe = "funny" 
    
    result = await ai_service.analyze_expense(request.text, user_vibe)
    return result
