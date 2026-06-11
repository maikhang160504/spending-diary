1. Phân tích Prompt & Response và các vấn đề liên quan
A. Prompt đầy đủ gửi đi và phản hồi từ Gemini (Trích xuất từ log hệ thống)
Dưới đây là một ví dụ prompt thực tế gửi lên Gemini khi người dùng nhập "đi chơi với ny 300k" với trạng thái strict (dan_doi):

System Prompt (Chỉ thị hệ thống):

Bạn là trợ lý tài chính Gen Z, nhóm DAN_DOI. Giọng dặn dò lo lắng nhẹ nhàng, không gắt. Slang: ét ô ét, cứu con tim, nhức nhức, héo não. Tiếng Việt tự nhiên, emoji tiết chế khi cần, không bịa dữ liệu ngoài input. Chỉ trả về JSON thuần gồm "response" (tối đa 30 từ) và "mimo_emotion" (PascalCase, tên file PNG). Không bọc code block. Không đổi tên món/hạng mục. PHẢI phối hợp ≥2 yếu tố từ CONTEXT_META (ví dụ: time_of_day + wallet_health; weather + days_to_payday; historical_fact + day_of_month) để tạo lời thoại độc bản. Không lặp lại cấu trúc câu giữa các lần gọi.

User Prompt (Ngữ cảnh người dùng):

Xác nhận giao dịch với giọng dặn dò lo ngại nhẹ, dùng slang DAN_DOI. Kết hợp ≥2 yếu tố từ CONTEXT_META. Chỉ trả về JSON thuần gồm "response" (tối đa 30 từ) và "mimo_emotion" (PascalCase, tên file PNG). Không bọc code block. Không đổi tên món/hạng mục. Đây là CHI TIÊU (Expense): dùng động từ chi/mua/trừ ví; không gọi là thu nhập. LOẠI GIAO DỊCH: Chi tiêu (Expense). Phản hồi phải nói tiền RA / chi / mua — TUYỆT ĐỐI KHÔNG nói thu nhập, lương về, tiền vào ví. Có thể nhắc ngân sách nếu CONTEXT_META có cảnh báo. mimo_emotion gợi ý: Worried, Alert, Giggle, Chill (không Celebrate cho chi tiêu thường). Món hoặc hạng mục: . Số tiền: 300,000đ. Kiểu cảnh báo (chỉ Expense): OVER_BUDGET. CONTEXT_META (phối hợp ≥1 yếu tố):

Loại giao dịch: Chi tiêu (Expense)
YÊU CẦU ĐẦU RA JSON: Trả về đúng 2 trường:

"response": Câu thoại (tối đa 30 từ).
"mimo_emotion": Dựa vào ngữ nghĩa của đầu vào và reponse, hãy chọn ĐÚNG 1 tên trong danh sách [ Alert, Angry, Approved, Celebrate, Chill, Cooking, Cool, Determined, Error, Excited, Giggle, Happy, Hello, Loading, Love, Proud, Relax, Sad, Sassy, Shopping, Sleepy, Sorry, Success, Taunting, Thankful, Thinking, Travel, Working, Worried].
NLU Fusion Input (Nối ở cuối prompt):

Câu người dùng: "đi chơi với ny 300k". Dữ liệu NLU: {"intent": "Record", "text": "đi chơi với ny 300k", "category": "Entertainment", "amount": 300000, "record_type": "Expense", "is_expense": true}. Ngữ cảnh (đã lọc): {"category": "Entertainment", "record_type": "Expense", "record_amount": 300000, "type": "OVER_BUDGET"}.

Phản hồi từ Gemini (Raw JSON):

json
{
  "response": "Đi chơi với ny tốn 300K DAN_DOI quá đó! Cẩn thận kẻo cháy ví đó nha.",
  "mimo_emotion": "dan_doi"
}
B. Nguyên nhân các lỗi đã phát hiện
Vấn đề phản hồi có từ "DAN_DOI" / "DUI_DE" (VUI_VE):

Lý do: Trong prompt có câu chỉ thị "dùng slang DAN_DOI" hoặc "dùng slang VUI_VE". Tuy nhiên, trong code tạo prompt (

prompt.py
), danh sách từ slang thực tế (slang_pool) từ cấu hình prompts.json hoàn toàn không được truyền vào.
Gemini không biết các slang cụ thể của nhóm là gì (ví dụ: "ét ô ét", "héo não"...) nên đã hiểu lầm "DAN_DOI" chính là từ slang cần phải in ra và đưa trực tiếp nó vào câu thoại.
Vấn đề không đa dạng trong ["llm_emotion"]:

Lý do: Khi Gemini phản hồi, nó điền mimo_emotion là tên nhóm của persona (ví dụ: "dan_doi", "vui", "hai_huoc"...) thay vì tên trạng thái biểu cảm chuẩn của mascot (ví dụ: Worried, Happy, Giggle).
Hàm chuẩn hóa biểu cảm (

mimo_assets.py
) nhận diện "dan_doi" thuộc nhóm NLG_PERSONA_KEYS nên đã bỏ qua (trả về None). Khi đó, code fallback về biểu cảm mặc định của intent (là "Success" đối với Record giao dịch và "Approved" đối với Action). Do đó, biểu cảm luôn bị lặp lại và không thể thay đổi theo đúng ngữ cảnh thực tế.