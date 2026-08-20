# Hướng dẫn thiết lập và vận hành mã nguồn thực nghiệm luận văn

Tài liệu này cung cấp đường dẫn mã nguồn, cấu hình môi trường, quy trình huấn luyện ban đầu các mô hình AI cùng hướng dẫn chi tiết các bước khởi chạy từng module trong hệ thống bao gồm AI Service, Backend, Web Admin và Mobile App.

---

## 1. Thông tin mã nguồn và tài nguyên thực nghiệm

Hệ thống mã nguồn của luận văn được tổ chức theo kiến trúc phân tán đa dịch vụ và lưu trữ trên nền tảng GitHub.

### 1.1 Liên kết mã nguồn và dữ liệu

| Thành phần | Nền tảng lưu trữ | Đường dẫn / Vị trí | Mô tả nội dung |
| --- | --- | --- | --- |
| Kho lưu trữ chính (Monorepo) | GitHub Repository | https://github.com/maikhang160504/spending-diary | Toàn bộ mã nguồn Backend, Web Admin, Mobile App |
| Kho lưu trữ dịch vụ AI (Submodule) | GitHub Repository | https://github.com/maikhang160504/genz-expense-ml | Dịch vụ AI Service, OCR Pipeline, NLU Pipeline |
| Bộ dữ liệu hóa đơn gốc | Kaggle Dataset | https://www.kaggle.com/datasets/domixi1989/vietnamese-receipts-mc-ocr-2021 | Tập dữ liệu MC_OCR 2021 phục vụ huấn luyện và kiểm thử trích xuất hóa đơn |
| Trọng số mô hình xoay ảnh MobileNetV3 | Pretrained MC_OCR | https://github.com/ndcuong91/MC_OCR | Trọng số đã huấn luyện sẵn cho mô hình xoay ảnh hóa đơn 0 và 180 độ |
| Trọng số mô hình nhận dạng chữ VietOCR | Pretrained VietOCR | https://github.com/pbcquoc/vietocr | Trọng số VGG-Transformer chuyên biệt cho chữ viết tiếng Việt |
| Mô hình phát hiện vùng chữ DBNet | Pretrained PaddleOCR | https://github.com/PaddlePaddle/PaddleOCR | Trọng số DBNet phát hiện khung bao văn bản hóa đơn |
| Trọng số mô hình trích xuất thực thể LayoutLMv3 | Tinh chỉnh sẵn trong dự án | `expense-ocr-nlu/bill_ocr/models/layoutlmv3/` | Trọng số model_best.pth đã tinh chỉnh trên tập MC_OCR 2021 |
| Trọng số mô hình phân loại NLU | Huấn luyện sẵn trong dự án | `expense-ocr-nlu/text_nlu/models/` | Trọng số bộ mã hóa PhoBERT và bộ phân loại danh mục, ý định |
| Mô hình nền tảng PhoBERT Base | Hugging Face Hub | https://huggingface.co/vinai/phobert-base | Mô hình ngôn ngữ tiếng Việt tiền huấn luyện |
| Mô hình nền tảng LayoutLMv3 Base | Hugging Face Hub | https://huggingface.co/microsoft/layoutlmv3-base | Mô hình ngôn ngữ đa phương thức và bố cục không gian |
| Mô hình nền tảng Qwen 2.5 Instruct | Hugging Face Hub | https://huggingface.co/Qwen/Qwen2.5-14B-Instruct | Mô hình ngôn ngữ lớn 14 tỷ tham số |

Bảng trên liệt kê các liên kết và vị trí lưu trữ tài nguyên thực nghiệm. Toàn bộ trọng số mô hình đã được đóng gói sẵn trong mã nguồn của dự án, người dùng không cần tải thêm thủ công khi chạy thử nghiệm cục bộ.

### 1.2 Tài khoản và dữ liệu mẫu thử nghiệm

Hệ thống được thiết lập sẵn tài khoản quản trị và tài khoản người dùng thử nghiệm phục vụ kiểm thử nhanh:
- Tài khoản quản trị viên: email `admin@moneystory.local`, mật khẩu `admin1234`
- Tài khoản người dùng mẫu: email `demo@money.local`, mật khẩu `demo1234`

---

## 2. Yêu cầu môi trường hệ thống

Để chạy lại toàn bộ hệ thống trên máy trạm cá nhân hoặc môi trường máy chủ, cần chuẩn bị các công cụ phần mềm sau:

| Phần mềm | Phiên bản khuyến nghị | Mục đích sử dụng |
| --- | --- | --- |
| Node.js | Phiên bản 18 trở lên hoặc phiên bản 20 LTS | Chạy Backend Orchestrator và xây dựng Web Admin |
| Python | Phiên bản 3.10 đến 3.13 | Chạy AI Service, các pipeline OCR, NLU và công cụ huấn luyện |
| Flutter SDK | Phiên bản 3.19 trở lên | Biên dịch và chạy ứng dụng di động Android và iOS |
| Git | Phiên bản 2.30 trở lên | Tải mã nguồn và quản lý các nhánh phát triển |
| CUDA Toolkit | Phiên bản 11.8 hoặc 12.1 | Hỗ trợ tăng tốc phần cứng GPU cho huấn luyện và suy luận AI |

Bảng trên tóm tắt các yêu cầu môi trường phần mềm nền tảng cần thiết trước khi bắt đầu quy trình cài đặt và thực thi các thành phần trong hệ thống.

---

## 3. Quy trình huấn luyện và cấu hình các mô hình AI

Hệ thống AI bao gồm ba nhóm mô hình chính: thị giác máy tính nhận diện hóa đơn, xử lý ngôn ngữ tự nhiên hiểu văn bản chi tiêu, và mô hình ngôn ngữ lớn hỗ trợ đối thoại tài chính. Dự án kết hợp việc tái sử dụng các mô hình đã được huấn luyện sẵn với việc tinh chỉnh chuyên sâu trên các tập dữ liệu thực tế.

### 3.1 Mô hình xoay ảnh hóa đơn MobileNetV3

Mô hình xoay ảnh giải quyết bài toán phân loại hướng nghiêng của ảnh hóa đơn hoặc từng dòng chữ được cắt ra, đưa ảnh về đúng chiều chuẩn 0 độ trước khi nhận dạng ký tự.

Dự án sử dụng trực tiếp trọng số đã được huấn luyện sẵn từ giải pháp Top 1 cuộc thi MC_OCR 2021 tại kho lưu trữ [ndcuong91/MC_OCR](https://github.com/ndcuong91/MC_OCR). Tệp trọng số `mobilenetv3-Epoch-487-Loss-0.03-Acc-0.99.pth` đã được tích hợp sẵn trong mã nguồn.

Trong trường hợp người phát triển cần huấn luyện lại mô hình từ đầu trên tập dữ liệu gốc:
1. Tập dữ liệu: Dữ liệu huấn luyện gồm các ảnh hóa đơn từ cuộc thi MC_OCR 2021 kết hợp các phép xoay nhân tạo 90 độ, 180 độ và 270 độ cùng kỹ thuật tăng cường độ sáng và độ tương phản.
2. Cấu trúc mô hình: Kiến trúc MobileNetV3 Small gọn nhẹ, nhận đầu vào ảnh xám kích thước 64x64 pixel hoặc 320x320 pixel và phân loại nhị phân hoặc đa lớp.
3. Quy trình thực hiện:
   ```bash
   cd expense-ocr-nlu/bill_ocr
   python -m mc_ocr.rotation_corrector.data_process
   python -m mc_ocr.rotation_corrector.train_config --cfg experiments/mobilenetv3_filtered_public_train.yaml
   ```

Bảng siêu tham số huấn luyện mô hình MobileNetV3:

| Siêu tham số | Giá trị thiết lập | Giải thích ý nghĩa |
| --- | --- | --- |
| Kích thước ảnh đầu vào | 64x64 hoặc 320x320 pixel | Chuẩn hóa kích thước khung hình trước khi đưa vào mạng |
| Thuật toán tối ưu | Adam | Thuật toán cập nhật trọng số thích ứng |
| Tốc độ học ban đầu | 0.001 | Tốc độ học khởi tạo cho bộ trích xuất đặc trưng |
| Kích thước lô | 64 | Số lượng mẫu xử lý đồng thời trong một bước lặp |
| Số lượng chu kỳ huấn luyện | 500 epochs | Tổng số vòng huấn luyện qua toàn bộ tập dữ liệu |
| Hệ số triệt tiêu Dropout | 0.2 | Tỷ lệ ngắt kết nối ngẫu nhiên để chống hiện tượng quá khớp |
| Hàm mất mát | Cross Entropy Loss | Đo lường độ sai lệch xác suất phân loại góc xoay |

Bảng trên chi tiết hóa các tham số huấn luyện mô hình MobileNetV3, giúp mô hình đạt độ chính xác trên 99 phần trăm sau 487 chu kỳ huấn luyện.

### 3.2 Mô hình nhận diện ký tự tiếng Việt VietOCR VGG-Transformer

Mô hình chuyển đổi các vùng ảnh dòng chữ đã được cắt và căn chỉnh thẳng thành chuỗi văn bản tiếng Việt có dấu hoàn chỉnh.

Dự án sử dụng trọng số mô hình VGG-Transformer đã được huấn luyện sẵn chuyên biệt cho tiếng Việt từ kho lưu trữ [pbcquoc/vietocr](https://github.com/pbcquoc/vietocr). Tệp trọng số `vgg_transformer.pth` đã được đóng gói sẵn trong thư mục `expense-ocr-nlu/bill_ocr/models/vietocr/`.

Trường hợp cần tinh chỉnh bổ sung trên tập dữ liệu chữ cắt thực tế từ hóa đơn bán lẻ MC_OCR 2021:
1. Tập dữ liệu: Kết hợp tập dữ liệu chữ tổng hợp tiếng Việt với dữ liệu chữ cắt thực tế từ hóa đơn bán lẻ MC_OCR 2021.
2. Cấu trúc mô hình: Bộ trích xuất đặc trưng hình ảnh VGG19 kết hợp khối giải mã Transformer đa đầu tự chú ý dạng chuỗi sang chuỗi.
3. Quy trình thực hiện:
   ```bash
   cd expense-ocr-nlu/bill_ocr
   python -m vietocr.train --config bill_ocr/models/vietocr/config.yml
   ```

Bảng siêu tham số tinh chỉnh mô hình VietOCR:

| Siêu tham số | Giá trị thiết lập | Giải thích ý nghĩa |
| --- | --- | --- |
| Chiều cao ảnh dòng | 32 pixel | Kích thước chiều cao chuẩn hóa của dòng chữ |
| Chiều rộng ảnh tối đa | 512 pixel | Chiều rộng tối đa cho phép của dòng chữ |
| Bộ giải mã | Transformer Seq2Seq | Kiến trúc chú ý đa đầu giải mã chuỗi ký tự |
| Thuật toán tối ưu | Adam | Bộ tối ưu hóa vi sai thích ứng |
| Tốc độ học | 0.0001 | Tốc độ học nhỏ nhằm duy trì các đặc trưng đã học từ trước |
| Kích thước lô | 32 | Số dòng chữ xử lý song song trên mỗi bước |
| Chiến lược tìm kiếm | Beam Search độ rộng 5 | Giải mã tìm chuỗi ký tự có xác suất cao nhất |

Bảng trên thể hiện các siêu tham số áp dụng cho giai đoạn tinh chỉnh mô hình VietOCR trên tập dữ liệu chữ hóa đơn tiếng Việt.

### 3.3 Mô hình trích xuất thực thể hóa đơn LayoutLMv3

Mô hình LayoutLMv3 tiếp nhận đồng thời ba luồng thông tin: hình ảnh hóa đơn, chuỗi văn bản trích xuất từ VietOCR ([pbcquoc/vietocr](https://github.com/pbcquoc/vietocr)) và tọa độ không gian 2D của các hộp bao từ PaddleOCR ([PaddlePaddle/PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR)) để gán nhãn thực thể bao gồm tên người bán, địa chỉ, ngày giờ và tổng tiền thanh toán.

Dự án khởi tạo từ mô hình nền tảng [microsoft/layoutlmv3-base](https://huggingface.co/microsoft/layoutlmv3-base) và tiến hành tinh chỉnh trên tập dữ liệu MC_OCR 2021 đã qua làm sạch. Trọng số sau tinh chỉnh `model_best.pth` được đóng gói sẵn trong thư mục `expense-ocr-nlu/bill_ocr/models/layoutlmv3/`.

1. Chuẩn bị và làm sạch dữ liệu:
   Loại bỏ các dòng nhãn sai chính tả, lọc bỏ các mẫu không đồng bộ giữa danh sách hộp bao và văn bản, chuẩn hóa tọa độ không gian về thang đo 0 đến 1000.
   ```bash
   cd expense-ocr-nlu
   python -m bill_ocr.layoutlmv3.scripts.filter_layoutlmv3_dataset --csv data/mcocr_train_df.csv --img_dir data/mc_ocr_train --out_csv data/mcocr_train_df_layoutlmv3_cleaned.csv --out_img_dir data/mc_ocr_train_layoutlmv3_cleaned
   ```
2. Khởi chạy huấn luyện cục bộ hoặc trên Modal GPU:
   ```bash
   # Chạy trên máy trạm cục bộ
   python -m bill_ocr.layoutlmv3.train_eval --epochs 15 --lr 5e-5 --batch-size 4
   
   # Chạy phân tán trên nền tảng Modal Serverless GPU
   modal run modal_app.py::train_layoutlmv3_model --num-epochs=15 --learning-rate=5e-5
   ```

Bảng siêu tham số huấn luyện mô hình LayoutLMv3:

| Siêu tham số | Giá trị thiết lập | Giải thích ý nghĩa |
| --- | --- | --- |
| Mô hình nền móng | microsoft/layoutlmv3-base | Mô hình ngôn ngữ đa phương thức thị giác và bố cục không gian |
| Chiều dài chuỗi tối đa | 512 tokens | Giới hạn số lượng thẻ từ trong một trang hóa đơn |
| Thuật toán tối ưu | AdamW | Bộ tối ưu hóa có trọng số phân rã |
| Tốc độ học | 0.00005 | Tốc độ học cho các lớp biến đổi đa phương thức |
| Phân rã trọng số | 0.01 | Hệ số chống quá khớp cho mạng sâu |
| Kích thước lô | 4 | Số lượng trang hóa đơn xử lý đồng thời |
| Số chu kỳ huấn luyện | 15 epochs | Tổng số chu kỳ huấn luyện |
| Cơ chế dừng sớm | 3 epochs | Dừng huấn luyện nếu điểm số F1 trên tập kiểm định không tăng |
| Thước đo đánh giá tối ưu | SeqEval Macro F1 | Điểm trung bình F1 theo từng loại thực thể thông tin |

Bảng trên tóm lược các siêu tham số then chốt giúp mô hình LayoutLMv3 đạt điểm số F1 cao nhất trong việc định danh các trường thông tin trên hóa đơn.

### 3.4 Mô hình phân loại ý định và danh mục NLU

Hệ thống NLU áp dụng kiến trúc hai tầng gồm mô hình cơ sở TF-IDF kết hợp LinearSVC và mô hình nâng cao sử dụng PhoBERT nhúng ngữ cảnh kết hợp bộ phân loại Logistic Regression được hiệu chỉnh xác suất.

1. Huấn luyện mô hình cơ sở TF-IDF kết hợp LinearSVC:
   ```bash
   cd expense-ocr-nlu
   python text_nlu/train/train_category_model.py
   python text_nlu/train/train_intent_model.py
   ```
2. Huấn luyện mô hình nâng cao PhoBERT Encoder:
   ```bash
   cd expense-ocr-nlu
   python text_nlu/train/train_category_encoder.py
   python text_nlu/train/train_intent_encoder.py
   ```

Bảng siêu tham số huấn luyện các mô hình NLU:

| Thành phần mô hình | Siêu tham số | Giá trị thiết lập | Mục đích sử dụng |
| --- | --- | --- | --- |
| TF-IDF Vectorizer | Dải n-gram | 1 đến 3 từ | Nắm bắt từ đơn, từ ghép và cụm ba từ tiếng Việt |
| TF-IDF Vectorizer | Số lượng đặc trưng tối đa | 8000 | Giới hạn kích thước từ điển đặc trưng quan trọng |
| LinearSVC | Trọng số phân lớp | Balanced | Cân bằng tỷ lệ mẫu giữa các lớp chi tiêu |
| PhoBERT Base | Chiều dài chuỗi tối đa | 96 cho danh mục, 128 cho ý định | Cắt hoặc đệm câu đầu vào theo độ dài phù hợp |
| PhoBERT Base | Kích thước lô nhúng | 8 mẫu | Trích xuất véc tơ đặc trưng 768 chiều theo lô |
| Bộ phân loại ngoài | Logistic Regression | Bộ giải L-BFGS, max_iter 4000 | Phân loại tuyến tính trên không gian véc tơ nhúng |
| Bộ hiệu chỉnh | CalibratedClassifierCV | 2-fold cross validation, phương pháp Sigmoid | Chuyển đổi khoảng cách lề thành xác suất tin cậy thực |

Bảng trên mô tả toàn bộ cấu hình huấn luyện của hệ thống NLU xử lý văn bản tiếng Việt từ tầng cơ sở đến tầng véc tơ ngữ cảnh chuyên sâu.

### 3.5 Mô hình ngôn ngữ lớn tài chính cá nhân Qwen2.5-14B qua QLoRA

Mô hình ngôn ngữ lớn đảm nhiệm việc phản hồi các câu thoại phiếm mang phong cách Gen Z, tư vấn tài chính và suy luận các câu mô tả chi tiêu phức tạp vượt ngoài khả năng của các mô hình phân loại truyền thống.

1. Kiến trúc: Mô hình nền tảng Qwen2.5-14B-Instruct được lượng tử hóa 4-bit dạng NormalFloat4 để giảm tải bộ nhớ đồ họa VRAM.
2. Kỹ thuật tinh chỉnh: Tinh chỉnh hiệu quả tham số bằng LoRA trên toàn bộ các ma trận trọng số biến đổi chú ý và mạng truyền thẳng đa tầng.
3. Lệnh khởi chạy huấn luyện trên cụm GPU Nvidia H100 qua Modal:
   ```bash
   cd expense-ocr-nlu
   modal run modal_app.py::train_qwen_model --num-epochs=3 --learning-rate=2e-4 --batch-size=4
   ```

Bảng siêu tham số tinh chỉnh mô hình Qwen2.5-14B QLoRA:

| Siêu tham số | Giá trị thiết lập | Giải thích ý nghĩa |
| --- | --- | --- |
| Mô hình gốc | Qwen/Qwen2.5-14B-Instruct | Mô hình ngôn ngữ lớn 14 tỷ tham số chất lượng cao |
| Chuẩn lượng tử hóa | 4-bit NF4 Double Quant | Nén trọng số gốc xuống 4-bit giúp tiết kiệm hơn 70 phần trăm VRAM |
| Kiểu dữ liệu tính toán | Bfloat16 | Định dạng dấu phẩy động 16-bit ổn định gradient |
| Hạng ma trận LoRA r | 16 | Số chiều không gian con xấp xỉ ma trận biến đổi |
| Hệ số tỷ lệ LoRA alpha | 32 | Hệ số khuếch đại ảnh hưởng của các tham số tinh chỉnh |
| Hệ số rơi LoRA Dropout | 0.05 | Tỷ lệ ngắt kết nối ngẫu nhiên chống quá khớp trên tập thoại |
| Các khối áp dụng LoRA | q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj | Toàn bộ ma trận chú ý và mạng truyền thẳng |
| Tốc độ học | 0.0002 | Tốc độ học cho các ma trận thích ứng LoRA |
| Tích lũy Gradient | 4 bước | Tăng kích thước lô hiệu dụng lên 16 mẫu |
| Kỹ thuật tiết kiệm bộ nhớ | Gradient Checkpointing | Tái tính toán lượt kích hoạt thay vì lưu toàn bộ trên VRAM |

Bảng trên trình bày các thông số kỹ thuật cho quá trình tinh chỉnh mô hình ngôn ngữ lớn Qwen2.5-14B phục vụ trợ lý tài chính thông minh.

---

## 4. Hướng dẫn chi tiết chạy demo từng module

Hệ thống được cấu trúc thành bốn thành phần hoạt động phối hợp thông qua các giao thức mạng RESTful API và WebSocket.

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                     │
│                  Giao diện người dùng cuối                  │
└──────────────┬───────────────────────────────▲──────────────┘
               │ HTTP REST                     │ WebSocket / HTTP
               ▼                               │
┌──────────────────────────────┐ ┌─────────────┴──────────────┐
│          AI Service          │ │    Backend Orchestrator    │
│    (FastAPI - Port 8000)     │ │   (Node.js - Port 4000)    │
│   OCR + NLU + Qwen LLM       │ │ CockroachDB + R2 + Token   │
└──────────────▲───────────────┘ └─────────────┬──────────────┘
               │                               │
               │ HTTP Sync & Retrain Data      │ Admin API
               └───────────────────────────────┼──────────────┐
                                               │              │
                                ┌──────────────▼──────────────┴┐
                                │          Web Admin           │
                                │     (React - Port 5173)      │
                                │  NLU Ops + Bill Retrain KIE  │
                                └──────────────────────────────┘
```

Sơ đồ trên mô tả luồng giao tiếp tương tác giữa bốn module chính trong kiến trúc tổng thể của hệ thống thực nghiệm.

### 4.1 Khởi chạy Module 1: AI Service (FastAPI)

AI Service tiếp nhận các yêu cầu bóc tách ảnh hóa đơn, phân tích văn bản ghi chép chi tiêu và sinh câu phản hồi thông minh.

#### Cách 1: Chạy cục bộ trên máy tính cá nhân

1. Di chuyển vào thư mục dịch vụ AI và kích hoạt môi trường ảo Python:
   ```powershell
   cd d:\Luan-Van\Project\expense-ocr-nlu
   # Kích hoạt môi trường ảo trên Windows PowerShell
   .\.venv\Scripts\Activate.ps1
   # Hoặc trên Linux/macOS: source .venv/bin/activate
   ```
2. Cài đặt các thư viện phụ thuộc:
   ```bash
   pip install -r requirements.txt
   ```
3. Cấu hình tệp biến môi trường `expense-ocr-nlu/.env`:
   ```ini
   HOST=0.0.0.0
   PORT=8000
   DEVICE=cpu
   USE_REAL_NLU=true
   USE_REAL_OCR=true
   RUN_LLM=1
   RUN_LLM_CHITCHAT=1
   LOG_MIMO_EMOTION=1
   LAZY_LOAD_MODELS=true
   ```
4. Khởi động dịch vụ FastAPI:
   ```bash
   uvicorn src.api.app:app --host 0.0.0.0 --port 8000 --reload
   ```
5. Kiểm tra trạng thái hoạt động:
   - Truy cập giao diện kiểm thử Swagger UI: `http://localhost:8000/docs`
   - Gọi kiểm tra sức khỏe hệ thống: `http://localhost:8000/health`

#### Cách 2: Triển khai trên máy chủ đám mây Modal Serverless GPU

Khi cần tăng tốc độ xử lý OCR bằng GPU L4 và chạy song song mô hình ngôn ngữ lớn Qwen trên GPU A10G:
```bash
cd d:\Luan-Van\Project\expense-ocr-nlu
# Đăng nhập tài khoản Modal
modal setup

# Chạy thử nghiệm có nóng mã nguồn
modal serve modal_app.py

# Hoặc triển khai chính thức lên máy chủ đám mây
modal deploy modal_app.py
```

### 4.2 Khởi chạy Module 2: Backend Orchestrator (Node.js Express)

Backend quản lý cơ sở dữ liệu CockroachDB, lưu trữ hình ảnh trên Cloudflare R2, xác thực người dùng bằng mã khóa JWT, hỗ trợ đồng bộ thời gian thực qua WebSocket và gửi thông báo đẩy Firebase Cloud Messaging.

1. Di chuyển vào thư mục Backend:
   ```powershell
   cd d:\Luan-Van\Project\app\backend
   ```
2. Cài đặt các gói phụ thuộc:
   ```bash
   npm install
   ```
3. Cấu hình tệp biến môi trường `app/backend/.env`:
   ```ini
   PORT=4000
   NODE_ENV=development
   DATABASE_URL=postgresql://<user>:<password>@<host>:26257/spending-stories?sslmode=verify-full
   DATABASE_SSL=true
   JWT_SECRET=chuoi_khoa_bi_mat_cho_jwt_token_an_toan
   JWT_ACCESS_TTL=900
   JWT_REFRESH_TTL=2592000
   AI_SERVICE_URL=http://localhost:8000
   R2_ACCOUNT_ID=ma_tai_khoan_cloudflare_r2
   R2_ACCESS_KEY_ID=khoa_truy_cap_r2
   R2_SECRET_ACCESS_KEY=khoa_bi_mat_r2
   R2_BUCKET=spending-stories
   R2_PUBLIC_BASE_URL=https://pub-spending-stories.r2.dev
   ```
4. Khởi tạo cấu trúc bảng và nạp dữ liệu mẫu ban đầu:
   ```bash
   # Tạo các bảng cơ sở dữ liệu CockroachDB
   npm run migrate
   
   # Nạp dữ liệu mẫu thử nghiệm
   npm run seed
   ```
5. Khởi động máy chủ Backend ở chế độ phát triển:
   ```bash
   npm run dev
   ```
6. Kiểm tra giao diện tài liệu API Swagger Backend: `http://localhost:4000/docs`

### 4.3 Khởi chạy Module 3: Web Admin (React + Vite)

Giao diện Web Admin phục vụ quản trị viên theo dõi độ sẵn sàng tái huấn luyện mô hình, kiểm tra các câu hiệu chỉnh của người dùng trên trang NLU Ops, và kiểm duyệt hộp bao văn bản trên trang Bill OCR Retrain.

1. Di chuyển vào thư mục Web Admin:
   ```powershell
   cd d:\Luan-Van\Project\app\frontend\web-admin
   ```
2. Cài đặt các thư viện giao diện:
   ```bash
   npm install
   ```
3. Khởi chạy máy chủ phát triển Vite:
   ```bash
   npm run dev
   ```
4. Truy cập bảng điều khiển quản trị: `http://localhost:5173`
   - Bảng tổng quan Dashboard: Xem các chỉ số hợp nhất và ngưỡng sẵn sàng huấn luyện lại
   - Quản trị hóa đơn Bill OCR Retrain: `/bill-retrain` duyệt dữ liệu hộp bao và trích xuất thực thể
   - Vận hành ngôn ngữ NLU Ops: `/nlu-ops` duyệt nhãn sửa đổi danh mục và kích hoạt huấn luyện lại
   - Giám sát người dùng User Inspector: `/user-inspector` xem lịch sử ghi chép theo từng tài khoản

### 4.4 Khởi chạy Module 4: Ứng dụng di động Mobile App (Flutter)

Ứng dụng di động Flutter cung cấp trải nghiệm ghi chép chi tiêu bằng giọng nói, chụp ảnh hóa đơn, theo dõi ngân sách thông minh và nhận gợi ý từ linh vật Mimo.

1. Di chuyển vào thư mục ứng dụng di động:
   ```powershell
   cd d:\Luan-Van\Project\app\frontend\mobile
   ```
2. Tải các gói phụ thuộc Flutter:
   ```bash
   flutter pub get
   ```
3. Cấu hình tệp `google-services.json` nhận dạng Firebase:
   Đặt tệp `google-services.json` vào thư mục `app/frontend/mobile/android/app/`.
4. Khởi chạy ứng dụng:
   - Khi chạy trên máy ảo Android Emulator:
     ```bash
     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000 --dart-define=AI_BASE_URL=http://10.0.2.2:8000
     ```
   - Khi chạy trên thiết bị thật kết nối chung mạng WiFi với máy chủ phát triển:
     ```bash
     # Thay thế địa chỉ IP bên dưới bằng địa chỉ mạng nội bộ của máy chủ phát triển
     flutter run --dart-define=API_BASE_URL=http://192.168.1.100:4000 --dart-define=AI_BASE_URL=http://192.168.1.100:8000
     ```

---

## 5. Quy trình kiểm thử nhanh hệ thống

Sau khi khởi chạy đầy đủ các dịch vụ, người dùng có thể thực hiện kiểm thử nhanh các điểm cuối API quan trọng bằng dòng lệnh PowerShell.

```powershell
# 1. Kiểm tra sức khỏe dịch vụ AI
Invoke-RestMethod -Uri "http://localhost:8000/health"

# 2. Kiểm thử khả năng suy luận NLU nhận diện câu chi tiêu
$bodyNlu = @{ text = "hôm nay ăn phở bò hết 45k" } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "http://localhost:8000/api/v1/nlu/infer" `
  -Body $bodyNlu -ContentType "application/json; charset=utf-8"

# 3. Đăng nhập hệ thống Backend lấy mã khóa JWT
$loginBody = @{ email = "demo@money.local"; password = "demo1234" } | ConvertTo-Json
$loginRes = Invoke-RestMethod -Method POST -Uri "http://localhost:4000/api/v1/auth/login" `
  -Body $loginBody -ContentType "application/json"
$token = $loginRes.data.accessToken

# 4. Lấy danh sách ví tiền của người dùng
Invoke-RestMethod -Uri "http://localhost:4000/api/v1/wallets" `
  -Headers @{ Authorization = "Bearer $token" }

# 5. Kiểm tra trạng thái sẵn sàng tái huấn luyện mô hình trên Backend
Invoke-RestMethod -Uri "http://localhost:4000/api/admin/retrain-readiness" `
  -Headers @{ Authorization = "Bearer $token" }
```

Quy trình kiểm thử trên xác nhận toàn bộ đường truyền giao tiếp giữa các thành phần đã sẵn sàng cho buổi trình diễn thực nghiệm.

---

## 6. Xử lý các sự cố thường gặp

Dưới đây là bảng hướng dẫn khắc phục các lỗi có thể phát sinh trong quá trình thiết lập và vận hành thử nghiệm.

| Hiện tượng lỗi | Nguyên nhân tiềm ẩn | Giải pháp khắc phục |
| --- | --- | --- |
| Lỗi thiếu tệp trọng số `ocr_loaded: false` | Thiếu tệp `vgg_transformer.pth` hoặc `model_best.pth` | Tải trọng số từ kho lưu trữ về thư mục `bill_ocr/models/vietocr` và `bill_ocr/models/layoutlmv3` |
| Lỗi kết nối mạng từ Mobile App sang Backend | Địa chỉ IP máy chủ không đúng với dải mạng của thiết bị | Chỉnh sửa tham số `API_BASE_URL` trỏ về `10.0.2.2` trên máy ảo hoặc địa chỉ IP nội bộ trên máy thật |
| Lỗi xác thực Google Sign-In trên Android | Thiếu mã băm dấu vân tay SHA-1 trong Firebase | Chạy lệnh `./gradlew signingReport` trong thư mục `android` và thêm mã SHA-1 vào bảng điều khiển Firebase |
| Tràn bộ nhớ VRAM khi chạy mô hình ngôn ngữ lớn | Bộ nhớ GPU không đủ để nạp toàn bộ tham số 14B | Thiết lập cờ `DEVICE=cpu` kết hợp sử dụng API đám mây hoặc kích hoạt chế độ lượng tử hóa 4-bit |
| Lỗi mất kết nối cơ sở dữ liệu CockroachDB | Đường dẫn chuỗi kết nối URL hoặc chứng chỉ SSL không hợp lệ | Kiểm tra lại thông số `DATABASE_URL` trong tệp cấu hình biến môi trường của Backend |

Bảng trên tổng kết các nguyên nhân gốc rễ và hướng dẫn khắc phục cụ thể cho các tình huống sự cố điển hình trong quá trình khởi chạy hệ thống.
