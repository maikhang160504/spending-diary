Dự án: Hệ thống quản lý chi tiêu cá nhân dạng Story
Vai trò: Kiến Trúc Sư Hệ Thống FinTech AI
Trọng tâm: Tối ưu hóa vòng lặp học chủ động (Active Learning Loop) và Quản lý hạ tầng GPU

PHẦN 1: CHIẾN LƯỢC HUẤN LUYỆN LẠI (INCREMENTAL VS. FULL RETRAINING)
Khi hệ thống tích lũy dữ liệu gán nhãn sạch từ WebAdmin, việc lựa chọn phương pháp nạp dữ liệu vào mô hình quyết định độ chính xác tổng thể của hệ thống FinTech.
1. Phân tích các phương pháp tiếp cận
Tiêu chí,Cách 1: Chỉ dùng Dữ liệu mới (Incremental/Fine-tuning),Cách 2: Gộp Dữ liệu cũ + Dữ liệu mới (Full Retraining)
Bản chất,"Nạp trọng số mô hình cũ, chỉ cho học tập dữ liệu mới vừa phát sinh từ WebAdmin.","Xóa bỏ trọng số cũ (hoặc dùng pre-trained gốc), huấn luyện lại toàn bộ kho dữ liệu từ đầu."
Ưu điểm,- Tốc độ cực nhanh (vài phút đến vài chục phút).- Tốn rất ít tài nguyên tính toán/GPU.,"- Độ ổn định hệ thống ở mức tối đa.- Mô hình có cái nhìn toàn diện, không thiên vị."
Nhược điểm,"Hiệu ứng ""Quên lãng thảm họa"" (Catastrophic Forgetting): Mô hình tối ưu hóa cho cấu trúc hóa đơn mới nhưng bị ""ngu đi"" hoặc đọc sai các định dạng hóa đơn cũ trước đây từng đọc rất tốt.",- Tốn chi phí hạ tầng và thời gian xử lý khi kho dữ liệu phình to lên hàng trăm nghìn mẫu.
2. Đề xuất kiến trúc cho từng thành phần Tech Stack
Hệ thống không áp dụng một công thức chung cho tất cả các mô hình, mà chia tách theo đặc thù thuật toán:

Mô hình Phân loại danh mục (TF-IDF + SVM): Luôn luôn Train lại từ đầu (Dữ liệu cũ + Dữ liệu mới).

Lý do: Khối lượng tính toán của SVM cực kỳ nhẹ, chỉ mất vài giây đến vài phút để khớp lại ma trận trên hàng trăm nghìn dòng text hóa đơn.

Mô hình OCR (PaddleOCR / VietOCR): Áp dụng Chiến lược Trộn dữ liệu thông minh (Data Rehearsal):

Cách làm: Tạo một tập dữ liệu huấn luyện hỗn hợp gồm 100% Dữ liệu mới kết hợp với 20% - 30% Dữ liệu cũ tiêu biểu (lấy ngẫu nhiên từ kho lịch sử).

Tác dụng: Phần dữ liệu cũ đóng vai trò là "liều nhắc lại" ngăn chặn hiện tượng quên lãng thảm họa mà vẫn tiết kiệm 70% thời gian train so với việc quét lại toàn bộ kho dữ liệu gốc.

PHẦN 2: KIẾN TRÚC KẾT NỐI TỰ ĐỘNG HÓA QUA KAGGLE API
Kaggle hoàn toàn có thể cấu hình làm môi trường tính toán từ xa (Remote GPU Compute Worker) cho WebAdmin thông qua Kaggle API.

1. Luồng vận hành hệ thống (Data Flow)
graph TD
    A[WebAdmin: Admin bấm nút 'Kích hoạt Huấn luyện'] --> B[Backend Server: Gom dữ liệu nhãn sạch]
    B --> C[Backend Server: Gọi Kaggle API đẩy Dataset mới]
    C --> D[Kaggle Server: Cập nhật Dataset Version]
    D --> E[Backend Server: Gọi lệnh 'Kaggle Kernels Push']
    E --> F[Kaggle GPU Instance: Chạy ngầm Notebook Huấn luyện]
    F --> G[Kaggle Server: Trả kết quả Model Artifacts .pth/.pdparams]
    G --> H[Cloud Storage / Backend Webhook: Thu hồi mô hình mới]

2. Các lệnh CLI cốt lõi triển khai tại Backend WebAdmin
Để thực hiện luồng tự động này, file cấu hình Token kaggle.json phải được phân quyền sẵn trên Server Backend.

Bước 1: Đẩy dữ liệu đồng bộ lên Kaggle Dataset
kaggle datasets version -p /app/storage/verified_ocr_labels -m "WebAdmin Auto-sync: Version $(date +'%Y%m%d')"
Bước 2: Triển khai và kích hoạt script huấn luyện chạy ngầm
kaggle kernels push -p /app/ai_pipeline/kaggle_notebook/

3. Những giới hạn chí mạng của Kaggle trong môi trường Production
Khi đưa giải pháp này vào vận hành thực tế cho một hệ thống FinTech, đội ngũ kỹ thuật cần đặc biệt lưu ý 3 rào cản từ nhà cung cấp miễn phí:

Giới hạn thời gian (Timeout): Tiến trình chạy ngầm (Save Version thông qua API) chỉ được thực thi tối đa 9 tiếng liên tục. Nếu tập dữ liệu lớn khiến việc fine-tune vượt ngưỡng này, Kaggle sẽ tự động ngắt kết nối và hủy bản build.

Hạn ngạch GPU (GPU Quota): Mỗi tài khoản bị giới hạn cứng 30 tiếng GPU/tuần. Do đó, trên WebAdmin không được phép cho trigger lệnh train tự động mỗi khi có hóa đơn mới, mà phải cấu hình gom theo lô (Batch) hoặc đặt lịch định kỳ (ví dụ: Chỉ chạy vào tối Chủ Nhật hàng tuần hoặc khi kho nhãn mới tích lũy đủ 2,000 mẫu).

Cơ chế thu hồi mô hình (Artifacts Retrieval): Máy ảo Kaggle sau khi chạy xong sẽ tự đóng băng. Code ở cuối Notebook bắt buộc phải tích hợp script tự động upload file trọng số (.pth hoặc .pdparams) lên một Cloud Storage (S3/Google Cloud Storage) hoặc bắn POST request gửi file trực tiếp về Endpoint Webhook của WebAdmin.

PHẦN 3: KIỂM CHỨNG CHẤT LƯỢNG MÔ HÌNH (QUALITY ASSURANCE GATE)
Để đảm bảo mô hình sau khi retrain không làm gián đoạn trải nghiệm của người dùng cuối (End-user), Backend WebAdmin bắt buộc phải chạy qua một bộ lọc độc lập trước khi deploy chính thức:

Xây dựng bộ kiểm thử cố định (Golden Test Set)
Chuẩn bị một tập hợp từ 200 - 500 ảnh hóa đơn đại diện cho tất cả các thương hiệu phổ biến (WinMart, Circle K, Highlands, Phúc Long, Hóa đơn điện/nước, tạp hóa nhỏ lẻ). Tập dữ liệu này đã được rà soát chuẩn xác 100%.

Quy tắc: Bộ dữ liệu này nằm riêng biệt, tuyệt đối không được đưa vào huấn luyện dưới bất kỳ hình thức nào.

Điều kiện phát hành (Release Condition):$$\text{Accuracy}_{\text{New Model}} \ge \text{Accuracy}_{\text{Current Model}}$$
Chỉ khi mô hình mới đạt điểm số chính xác trên bộ Golden Test Set bằng hoặc vượt trội hơn mô hình hiện tại trên Production, WebAdmin mới kích hoạt đổi Router chỉ định mô hình mới hoạt động. Nếu điểm số bị sụt giảm (mô hình bị hiện tượng quá khớp - Overfitting), hệ thống lập tức hủy bản build và gửi cảnh báo về cho đội ngũ AI Engineer.