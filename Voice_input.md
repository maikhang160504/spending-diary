giọng nói chính là vũ khí tối thượng giúp hiện thực hóa tư duy sản phẩm: "Giảm ma sát nhập liệu xuống mức tối thiểu". Thay vì mở app, chọn danh mục, gõ số tiền, gõ ghi chú (mất khoảng 15-20 giây), người dùng chỉ cần nhấn giữ một nút và nói một câu tự nhiên: "Trưa nay ăn bún đậu mắm tôm với đồng nghiệp hết 120 cành" (mất đúng 3 giây). Hệ thống phải tự bóc tách ra số tiền, danh mục và lưu thành một "Story" trên Timeline.

Dưới đây là thiết kế kiến trúc và giải pháp xử lý luồng Voice toàn diện cho hệ thống của chúng ta:
1. Hiện trạng & Thách thức (The Pain Points)
Ngôn ngữ tự nhiên tiếng Việt phức tạp: Người Việt sử dụng rất nhiều tiếng lóng khi tiêu tiền (ví dụ: "cành", "k", "loét", "vài chục", "một lít"). Nếu dùng các bộ thư viện chuyển giọng nói thành văn bản (Speech-to-Text) thông thường, hệ thống sẽ trả về chữ viết thô và không hiểu ngữ cảnh tài chính.

Nhiễu môi trường: Người dùng thường có nhu cầu nhập liệu ngay khi vừa tiêu tiền xong (ở quán ăn ồn ào, ngoài đường, quán cafe). Sóng âm bị nhiễu sẽ làm giảm độ chính xác của văn bản đầu ra.

Thách thức bóc tách dữ liệu: Khi có được đoạn văn bản thô (Text), làm sao cấu trúc hóa nó thành các trường dữ liệu cụ thể (Amount, Category, Note) để nạp vào PostgreSQL một cách chính xác mà không làm nghẽn hệ thống?

2. Giải pháp: Kiến trúc xử lý Voice 3 bước (Voice Processing Pipeline)
Để giải quyết bài toán này một cách thực tế với Tech Stack hiện tại, hệ thống Backend Python của chúng ta sẽ xử lý luồng Voice qua 3 thực thể độc lập:

Bước 1: Trích xuất âm thanh & Chuyển đổi văn bản (Audio-to-Text)

Client (Flutter): Sử dụng microphone ghi âm luồng trực tiếp, nén định dạng âm thanh nhẹ (như .m4a hoặc .wav tần số 16kHz) để giảm dung lượng mạng, sau đó đẩy API lên Python Backend.

Backend: Sử dụng một dịch vụ Speech-to-Text (STT) mạnh mẽ về tiếng Việt (như OpenAI Whisper bản Fine-tuned tiếng Việt hoặc các API nội địa như VinWave/FPT) để chuyển audio thành một chuỗi văn bản thô (Raw Text).

Bước 2: Chuẩn hóa tiếng lóng tài chính (Text Normalization)
Văn bản thô sau khi chuyển đổi cần đi qua một bộ lọc quy tắc (Rule-based Regex) kết hợp thuật toán khoảng cách từ để chuyển các từ lóng tiền tệ về dạng số chuẩn trước khi đưa vào mô hình phân tích sâu:120 cành/k $\rightarrow$ 1200001 lít / 1 xị $\rightarrow$ 100000Nửa triệu $\rightarrow$ 500000

Bước 3: Trích xuất thực thể & Gán nhãn (NER & Classification)Trích xuất Số tiền (Amount) và Thời gian (Date): Dùng Regular Expression (Regex) và thư viện xử lý ngôn ngữ tự nhiên tiếng Việt (như underthesea hoặc PhoNER) để bóc tách con số và mốc thời gian (ví dụ: "trưa nay" $\rightarrow$ ngày hiện tại, giờ trưa).Phân loại Danh mục (Category): Lấy chuỗi text hành vi (ví dụ: "ăn bún đậu mắm tôm") đi qua bộ vector hóa TF-IDF và đưa vào model Logistic Regression/SVM có sẵn của chúng ta để gán nhãn vào danh mục hệ thống (ví dụ: Ăn uống).

3. Thiết kế Luồng dữ liệu & Mã giả (Logic Design & Pseudo-code)
Luồng Logic phối hợp (Voice Input Flow)
[Flutter: Giữ nút Nói] ──(File Audio)──> [Backend Python: STT Engine]
                                                   │
                                            (Văn bản thô)
                                                   │
                                                   ▼
                                        [Bộ chuẩn hóa Tiếng lóng]
                                                   │
                                            (Văn bản chuẩn)
                                                   │
                                     ┌─────────────┴─────────────┐
                                     ▼                           ▼
                           [Regex / NER Extract]       [TF-IDF + Logistic Regression]
                             (Amount, Date)                   (Category)
                                     └─────────────┬─────────────┘
                                                   ▼
                                      [Logic Fusion & Save DB]
                                      (Tạo Story trên Timeline)

4. Lưu ý quan trọng khi thiết kế Trải nghiệm & Hệ thống (Product & Tech Notes)
Xử lý trường hợp không trích xuất được số tiền: Giọng nói có thể bị mất chữ khiến Regex không tìm thấy số tiền (ví dụ người dùng chỉ nói: "Ăn trưa bún đậu" mà quên nói giá). Hệ thống không được báo lỗi ngay, hãy kích hoạt cơ chế Fallback: Lưu giao dịch vào trạng thái Chờ (Draft), hiển thị trên Timeline dạng Story một thẻ màu vàng kèm icon Micro: "Bạn quên chưa nhập số tiền cho bữa ăn trưa, chạm vào đây để sửa nhanh nhé!".

Tối ưu hóa UI/UX trên App (Flutter): Nút ghi âm nên được thiết kế to, nằm ngay chính giữa thanh điều hướng (Bottom Navigation Bar). Hỗ trợ hiệu ứng sóng âm (Waveform) chuyển động theo giọng nói thật để tạo cảm giác tương tác sinh động cho cấu phần "Story".

Logic Fusion (Kết hợp Voice + Ảnh): Đây là kịch bản rất hay: Người dùng vừa chụp hóa đơn (chỉ có số tiền, không rõ danh mục) vừa bấm giữ micro nói: "Cái này là tiền mua quà sinh nhật cho người yêu". Lúc này, hệ thống sẽ chạy Logic Fusion: Lấy Amount từ OCR của hóa đơn (vì OCR chuẩn xác hơn), và lấy Category + Note từ đoạn Voice này để tạo nên một Story hoàn chỉnh nhất.

