const aiService = require('./aiService');
const db = require('../models'); // Gi? s? d�ng Sequelize/Prisma
const { v4: uuidv4 } = require('uuid');

class StoryService {
    /**
     * T?o Story m?i - Tr�i tim c?a h? th?ng
     * @param {Object} userData { userId, userText, imageFile }
     */
    async createStory({ userId, userText, imageFile }) {
        // 1. G?i AI Service d? b�c t�ch ?nh v� ph�n t�ch text
        // AI tr? v?: { ocr_amount, ai_category, merchant, mimo_comment, raw_ocr }
        const aiResult = await aiService.processInput(imageFile, userText);

        // 2. Data Fusion Logic - "Xuong m�u" n?m ? d�y
        const finalData = this._executeDataFusion(userText, aiResult);

        // 3. Chu?n b? Metadata JSONB cho PostgreSQL
        const metadata = {
            merchant_name: aiResult.merchant || 'Unknown',
            ai_confidence: aiResult.confidence,
            mimo_insight: aiResult.mimo_comment,
            raw_ocr_data: aiResult.raw_ocr, // Luu l?i d? sau n�y re-train
            processed_at: new Date().toISOString()
        };

        // 4. Ghi vào Database (Sử dụng Transaction để đảm bảo tính nhất quán và RLS)
        const transaction = await db.sequelize.transaction();
        try {
            // Thiết lập RLS (Row-Level Security) an toàn cho Transaction này
            await db.sequelize.query(
                `SET LOCAL app.current_user_id = '${userId}'`, 
                { transaction }
            );

            const newStory = await db.Transaction.create({
                id: uuidv4(),
                user_id: userId,
                amount: finalData.amount,
                category_id: finalData.categoryId,
                note: userText,
                image_url: imageFile ? imageFile.path : null, // �u?ng d?n S3/Local
                metadata: metadata,
                status: 'COMPLETED'
            }, { transaction });

            // Luu �: Trigger t?i Postgres s? t? d?ng c?p nh?t b?ng financial_summaries
            await transaction.commit();
            
            return {
                ...newStory.toJSON(),
                mimo_say: aiResult.mimo_comment // Tr? v? cho UI hi?n th? Pop-up Mimo
            };
        } catch (error) {
            await transaction.rollback();
            throw error;
        }
    }

    /**
     * Private Method: Th?c thi quy t?c uu ti�n d? li?u
     */
    _executeDataFusion(userText, aiResult) {
        // A. Tr�ch xu?t s? ti?n t? Text ngu?i d�ng b?ng Regex don gi?n
        // V� d?: "An ph? 65k" -> 65000
        const amountFromText = this._extractAmountFromText(userText);

        // B. Quy?t d?nh S? ti?n (Priority: User Text > OCR)
        const finalAmount = amountFromText || aiResult.ocr_amount || 0;

        // C. Quy?t d?nh Danh m?c (Priority: User Text Intent > AI Classify)
        // Gi? s? aiService d� map intent t? text th�nh categoryId
        const finalCategory = aiResult.user_intent_category || aiResult.ai_category;

        return {
            amount: finalAmount,
            categoryId: finalCategory
        };
    }

    _extractAmountFromText(text) {
        if (!text) return null;
        let cleanText = text.toLowerCase();
        
        // Remove accents
        cleanText = cleanText.replace(/à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ/g, "a");
        cleanText = cleanText.replace(/è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ/g, "e");
        cleanText = cleanText.replace(/ì|í|ị|ỉ|ĩ/g, "i");
        cleanText = cleanText.replace(/ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ/g, "o");
        cleanText = cleanText.replace(/ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ/g, "u");
        cleanText = cleanText.replace(/ỳ|ý|ỵ|ỷ|ỹ/g, "y");
        cleanText = cleanText.replace(/đ/g, "d");

        // Regex mở rộng cho tiếng Việt lóng
        const regex = /(\d+(?:\.\d+)?)\s*(k|tr|trieu|cu|lit|vnd|d)/i;
        const match = cleanText.match(regex);
        
        if (match) {
            let value = parseFloat(match[1]);
            const unit = match[2];
            
            if (unit === 'k') value *= 1000;
            if (['tr', 'trieu', 'cu'].includes(unit)) value *= 1000000;
            if (['lit'].includes(unit)) value *= 100000; // 1 lít = 100k
            
            return value;
        }
        return null;
    }
}

module.exports = new StoryService();
