import re
import os
import joblib
from decimal import Decimal
from app.schemas.index import AIAnalysisResponse

class AIService:
    def __init__(self):
        # Load model khi khởi động Server
        model_path = os.path.join(os.path.dirname(__file__), '..', 'core', 'expense_classifier.pkl')
        try:
            self.model = joblib.load(model_path)
        except Exception:
            self.model = None

    @staticmethod
    def extract_amount(text: str) -> Decimal:
        """Sử dụng Regex để bóc tách tiền bạc chuẩn xác và siêu tốc"""
        # Pattern tìm số kèm đơn vị đặc thù văn nói: k, cành, tr, triệu
        pattern = r'(\d+(?:\.\d+)?)\s*(k|cành|tr|triệu|vnd|vnđ|đ)?'
        match = re.search(pattern, text.lower())
        if match:
            value = float(match.group(1))
            unit = match.group(2)
            if unit in ['k', 'cành']: value *= 1000
            elif unit in ['tr', 'triệu']: value *= 1000000
            return Decimal(str(value))
        return Decimal("0")

    def predict_category(self, text: str) -> str:
        # Load prediction từ SVM Model (đã khởi tạo trong __init__)
        if self.model:
            try:
                prediction = self.model.predict([text.lower()])
                return prediction[0]
            except Exception:
                pass
        
        # Fallback về Mock nếu chưa có Model
        if "phở" in text.lower() or "ăn" in text.lower():
            return "Ăn uống"
        return "Khác"

    async def call_llm_for_comment(self, amount: Decimal, category: str, text: str, user_vibe: str) -> tuple[str, str]:
        from app.core.prompts import ROAST_PROMPT, HEALING_PROMPT
        
        # Chọn template dựa trên vibe
        system_base = ROAST_PROMPT if user_vibe == "funny" else HEALING_PROMPT
        prompt = system_base.format(amount=amount, category=category, text=text)
        
        # TODO: Cắm Google Generative AI / OpenAI API ở đây
        # Ví dụ: response = await genai_model.generate_content(prompt)
        # Tạm thời Mock Output:
        
        if user_vibe == "funny" and category == "Ăn uống":
            mock_comment = f"Ăn phở {int(amount/1000)}k? Thôi xong, ví Khang sắp 'văng' rồi!"
            mock_mood = "smirk"
        else:
            mock_comment = "Khang xài tiền thế này thì quản gia cũng trầm cảm"
            mock_mood = "annoyed"
            
        return (mock_comment, mock_mood)

    async def analyze_expense(self, text: str, user_vibe: str) -> AIAnalysisResponse:
        # Pipeline 3 bước: Regex (Tốc độ) -> SVM (Phân loại) -> LLM (Sáng tạo)
        
        # Bước 1: Bóc lượng 
        amount = self.extract_amount(text)
        
        # Bước 2: Bóc tag (Machine Learning cổ điển)
        category = self.predict_category(text) 
        
        # Bước 3: Lấy Mood ngay lập tức bằng Logic (Không đợi LLM)
        from app.services.mood_engine import MoodEngine
        instant_mood = MoodEngine.get_instant_mood(text, amount, user_vibe)
        
        # Bước 4: Render AI Comment & Mascot Emotion
        ai_comment, _ = await self.call_llm_for_comment(
            amount, category, text, user_vibe
        )
        
        return AIAnalysisResponse(
            amount=amount,
            category=category,
            ai_comment=ai_comment,
            mascot_mood=instant_mood
        )
