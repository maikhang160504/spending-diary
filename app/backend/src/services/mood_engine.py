from decimal import Decimal

class MoodEngine:
    # Định nghĩa các bộ từ khóa cảm xúc
    KEYWORDS = {
        "happy": ["thưởng", "lãi", "tặng", "quà", "vui", "hên"],
        "crying": ["nợ", "phạt", "mất", "hết", "đau", "hỏng", "sửa"],
        "heart_eyes": ["người yêu", "vợ", "bạn gái", "crush", "date"],
    }

    @staticmethod
    def get_instant_mood(text: str, amount: Decimal, vibe: str) -> str:
        text_lower = text.lower()
        
        # 1. Ưu tiên Logic số tiền (Shock)
        if amount > 1000000: # Ví dụ chi trên 1 triệu là giật mình
            return "shocked"
        
        # 2. Logic dựa trên từ khóa (Sentiment)
        for mood, keys in MoodEngine.KEYWORDS.items():
            if any(key in text_lower for key in keys):
                return mood
        
        # 3. Logic dựa trên Vibe cài đặt
        if vibe == "funny":
            return "smirk"
            
        return "happy" # Mặc định
