const axios = require('axios');

class AIService {
    async processInput(image, userText) {
        // Trong th?c t? s? g?i: 
        // return await axios.post(process.env.AI_SERVICE_URL, formData, config);
        
        // Mock data d? Frontend làm vi?c:
        return {
            ocr_amount: 65000,
            ai_category: "uuid-of-dining-category",
            merchant: "Ph? Thìn Lò Ðúc",
            mimo_comment: "Ngon dó! Nhung ti?t ki?m thêm chút nha ??",
            confidence: 0.95,
            raw_ocr: "Ph? Thìn Lò Ðúc\nS? ti?n: 65.000d\n..."
        };
    }
}

module.exports = new AIService();
