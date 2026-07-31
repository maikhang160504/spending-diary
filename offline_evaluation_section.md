#### 5.3.1. Kết quả huấn luyện và đánh giá ngoại tuyến (Offline Evaluation)

Đánh giá ngoại tuyến (Offline Evaluation) được thực hiện trên tập dữ liệu kiểm thử (Test Set) được chia tách tự động từ tập dữ liệu huấn luyện với tỷ lệ chuẩn. Mục đích của việc đánh giá này là kiểm định khả năng học tập, khái quát hóa (generalization) của các mô hình trên dữ liệu tĩnh trước khi đưa vào môi trường thực tế.

Trong khuôn khổ của đề tài, hai phương pháp tiếp cận học máy giám sát (Supervised Learning) là **TF-IDF + Support Vector Classifier (SVC/Logistic Regression)** và **PhoBERT (Transformer-based Encoder)** được huấn luyện và trích xuất độ đo. Đối với mô hình **Qwen 2.5 (Large Language Model)**, do bản chất là mô hình sinh ngôn ngữ lớn dựa trên học máy không giám sát (few-shot/zero-shot prompting), việc đánh giá hiệu năng chủ yếu được thực hiện ở tập chuẩn đối sánh trực tuyến (Online Benchmark). 

Dưới đây là kết quả thống kê hiệu năng chi tiết dựa trên các độ đo phân lớp cơ bản (Accuracy, Precision, Recall, F1-Score) cho các tác vụ NLU chính.

**1. Kết quả huấn luyện Mô hình Thống kê từ vựng (TF-IDF)**

Mô hình học máy truyền thống sử dụng đặc trưng TF-IDF cho thấy hiệu năng khá ấn tượng trên các bài toán phân lớp đơn giản, nhưng bắt đầu bộc lộ hạn chế ở các tác vụ phân loại đa lớp phức tạp (như Category).

*   **Tác vụ phân loại Ý định (Intent Classification):**
    *   Độ chính xác (Accuracy): **99.54%**
    *   F1-Score (Macro): **99.55%**
    *   *Nhận xét:* TF-IDF xử lý rất tốt việc phân tách ba ý định chính (Action, Record, Chitchat) do sự khác biệt lớn về từ vựng giữa các lớp này.

*   **Tác vụ phân loại Thể loại (Category Classification):**
    *   Độ chính xác (Accuracy): **95.86%**
    *   F1-Score (Macro): **94.02%**
    *   *Nhận xét:* Sự sụt giảm độ chính xác xuất hiện khi hệ thống phải phân loại thành 18 nhãn thể loại khác nhau (Food, Transport, Housing,...). Các nhãn có độ chồng chéo ngữ nghĩa cao như "Business" (F1 = 85.77%), "Social" (F1 = 88.16%) hoặc "Debt" (F1 = 88.88%) thường bị nhầm lẫn, do TF-IDF không có khả năng hiểu ngữ cảnh sâu xa của từ vựng.

**2. Kết quả huấn luyện Mô hình Học sâu (PhoBERT Encoder)**

Mô hình PhoBERT, nhờ áp dụng cơ chế Self-Attention từ kiến trúc Transformer, đã giải quyết triệt để các hạn chế của TF-IDF bằng cách hiểu biểu diễn chuỗi ngữ cảnh.

*   **Hiệu năng trên các tác vụ Phân lớp cấp độ Câu (Sentence-level Classification):**
    *   **Ý định (Intent):** Accuracy = **100.0%** | F1-Score = 100.0%
    *   **Loại hành động (Action Type):** Accuracy = **100.0%** | F1-Score = 100.0%
    *   **Loại bản ghi (Record Type):** Accuracy = **98.0%** | F1-Score = 95.0%
    *   **Thể loại chi tiêu (Category):** Accuracy = **96.0%** | F1-Score = 94.0%
    *   *Nhận xét:* Ở cấp độ câu, PhoBERT gần như đạt độ chính xác tuyệt đối trên các bài toán phân loại ý định và hành động. Đối với phân loại thể loại (Category), PhoBERT đạt 96.0%, nhỉnh hơn TF-IDF, chứng tỏ khả năng bắt ngữ cảnh từ tốt hơn khi có sự xuất hiện của các từ đồng nghĩa hoặc câu có cấu trúc phức tạp.

*   **Hiệu năng trên các tác vụ Trích xuất thực thể và Slot (Token-level Classification):**
    *   **Nhận dạng Thực thể có tên (NER):** Đạt mức F1-Score rất cao là **99.76%** (Precision: 99.71%, Recall: 99.81%). 
    *   **Điền khe giá trị (Slot Filling):** Mô hình được huấn luyện trên 11 trường thông tin (classifier & regressor). Mức F1-Score trung bình cho tất cả các khe (Weighted F1) đạt **98.13%**, độ chính xác trung bình đạt **97.96%**. Các trường phức tạp như `time_range` đạt F1 = 89.33%, `category_code` đạt 96.68%, và các trường trích xuất tên gọi (`value_text`, `goal_name`) đều đạt F1 > 99%.

**Bảng Tổng hợp So sánh Hiệu năng Ngoại tuyến (Offline Performance)**

| Tác vụ (Task) | Metric | TF-IDF | PhoBERT | Qwen 2.5 (LLM) |
| :--- | :---: | :---: | :---: | :---: |
| Phân loại Ý định (Intent) | Accuracy | 99.54% | **100.0%** | *Zero-shot / Đánh giá Online* |
| Phân loại Thể loại (Category)| Accuracy | 95.86% | **96.00%** | *Zero-shot / Đánh giá Online* |
| Trích xuất Thực thể (NER) | F1-Score | - | **99.76%** | *Zero-shot / Đánh giá Online* |
| Phân tích Slot (Slot Filling)| F1-Score (Avg) | - | **98.13%** | *Zero-shot / Đánh giá Online* |

**Nhận xét chung về quá trình huấn luyện ngoại tuyến:**
Sự chuyển dịch từ phương pháp thống kê (TF-IDF) sang học sâu (PhoBERT) cho thấy sự cải thiện đáng kể không chỉ ở điểm số mà còn ở tính đa dụng (xử lý được cả bài toán token-level như NER và Slot Filling thay vì chỉ phân loại). Mặc dù kết quả trên tập kiểm thử tĩnh rất cao (đạt ngưỡng >95%), nhưng tập dữ liệu này vẫn có tính chất "lý tưởng hóa" do được chia tách từ cùng một phân phối với tập huấn luyện. Để đánh giá chính xác khả năng chịu lỗi (fault tolerance) trước các biến thể ngôn ngữ tự nhiên phi chuẩn mực ngoài thực tế, hệ thống bắt buộc phải được chuẩn đối sánh bằng tập kiểm thử trực tuyến (Online Benchmark).
