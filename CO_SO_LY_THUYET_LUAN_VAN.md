# CHƯƠNG 2: CƠ SỞ LÝ THUYẾT TOÀN DIỆN VỀ HỆ THỐNG TRÍCH XUẤT HÓA ĐƠN & PHÂN TÍCH CHI TIÊU

Chương này trình bày các cơ sở khoa học, mô hình toán học và công nghệ lõi làm nền tảng cho hệ thống MoneyStory. Nội dung tập trung vào lý thuyết nhận dạng tài liệu thông minh (Document AI), phân tích ngôn ngữ tự nhiên (NLU), xử lý ảnh số và nhận dạng ký tự quang học (OCR), kiến trúc dữ liệu phân tán và cơ chế lưu trữ đám mây.

---

## 2.1. TỔNG QUAN VỀ HỆ THỐNG TRÍCH XUẤT THÔNG TIN TÀI LIỆU (DOCUMENT AI)

Trích xuất thông tin từ tài liệu có cấu trúc không đồng nhất (Key Information Extraction - KIE) là một bài toán cốt lõi trong lĩnh vực Trí tuệ nhân tạo và Thị giác máy tính ứng dụng [1]. Sự phát triển của các phương pháp trích xuất thông tin hóa đơn được chia làm bốn thế hệ công nghệ chính:

### 2.1.1. Phương pháp dựa trên luật (Rule-based & Heuristics)
Phương pháp sơ khai sử dụng bộ nhận dạng OCR kết hợp các quy tắc định sẵn (như biểu thức chính quy - Regular Expressions, hoặc bản đồ tọa độ cố định - Template Matching). Phương pháp này có độ phức tạp tính toán thấp nhưng gặp hạn chế lớn do cấu trúc hóa đơn trong thực tế cực kỳ đa dạng và không có quy chuẩn chung. Chỉ cần một thay đổi nhỏ về layout hoặc lỗi sai chính tả trong kết quả OCR thô (ví dụ: `T0TAL` thay vì `TOTAL`) sẽ làm hỏng hoàn toàn các quy tắc so khớp tĩnh.

### 2.1.2. Phương pháp dựa trên mạng đồ thị liên kết không gian (Graph Convolutional Networks - GCN)
Thế hệ thứ hai tiếp cận hóa đơn dưới dạng cấu trúc hình học phi Euclid. Các bounding box chứa chữ được coi là các đỉnh (nodes) trong một đồ thị, và mối quan hệ vị trí không gian (khoảng cách, căn dòng, góc lệch) được biểu diễn bằng các cạnh (edges) [2]. 

Mô hình **PICK (Processing Key Information Extraction)** đại diện tiêu biểu cho hướng đi này. PICK sử dụng mạng tích chập đồ thị cải tiến (Improved Graph Relation Networks) để tổng hợp các đặc trưng ngữ nghĩa văn bản (Textual) trích xuất từ BiLSTM và đặc trưng hình ảnh trực quan (Visual) trích xuất từ ResNet. Bằng việc lan truyền thông tin qua mạng chú ý đồ thị (Graph Attention Network - GAT), mô hình học được mối liên hệ không gian giữa nhãn thực thể và giá trị tương ứng (ví dụ: nhãn "Tổng tiền:" và con số "50.000đ" nằm ngang hàng) mà không bị phụ thuộc vào thứ tự dòng chữ đọc được.

### 2.1.3. Phương pháp biến thế đa phương thức (Multimodal Transformers)
Khắc phục nhược điểm của việc trích xuất đặc trưng hình ảnh và văn bản rời rạc của GCN, mô hình **LayoutLMv3** giới thiệu kiến trúc Transformer đa phương thức hợp nhất [3]. LayoutLMv3 học đồng thời cả ba thành phần dữ liệu:
- **Văn bản (Text)**: Chuỗi ký tự biểu diễn ngữ nghĩa.
- **Bố cục (Layout)**: Tọa độ bounding box 2D $[x_0, y_0, x_1, y_1]$ được mã hóa dưới dạng nhúng không gian (2D Spatial Position Embeddings).
- **Hình ảnh (Image)**: Các mảnh ảnh (linear projection of image patches) trích xuất trực tiếp từ vùng tài liệu tương ứng.

Mô hình sử dụng hai tác vụ huấn luyện tiên quyết (Pre-training objectives) chuyên biệt:
1. **Masked Language Modeling (MLM)**: Che các từ văn bản và yêu cầu mô hình đoán lại dựa trên bố cục không gian và hình ảnh xung quanh.
2. **Masked Image Modeling (MIM)**: Che các mảnh ảnh trực quan và yêu cầu mô hình tái tạo dựa trên ngữ nghĩa văn bản liền kề, giúp tối ưu hóa khả năng căn chỉnh ngữ nghĩa chéo (cross-modal alignment).

### 2.1.4. Mô hình thị giác - ngôn ngữ lớn (Vision-Language Models - VLM)
Thế hệ mới nhất áp dụng các mô hình nền tảng đa phương thức (Multimodal Foundation Models) như **Qwen-VL** hoặc **Qwen2-VL** [4]. Khác với LayoutLMv3 yêu cầu một bộ phát hiện chữ (OCR Detector) chạy trước để định vị tọa độ, VLM tiếp cận theo hướng End-to-End (Image-to-Text). Ảnh hóa đơn được mã hóa trực tiếp qua một mạng ViT (Vision Transformer) kết hợp bộ điều hợp (Visual-Language Adapter) để đưa vào mô hình ngôn ngữ lớn (LLM). 

VLM có khả năng hiểu trực tiếp cấu trúc hóa đơn dưới dạng câu hỏi đáp tự nhiên (Visual Question Answering - VQA), trích xuất thông tin trực tiếp ra định dạng JSON mà không cần lập trình các bước hậu xử lý hình học phức tạp. Hệ thống MoneyStory tận dụng sức mạnh của **Qwen2.5-14B-Instruct** để tinh chỉnh (Fine-tune) bằng phương pháp **LoRA (Low-Rank Adaptation)** trên hạ tầng GPU đám mây Modal để xử lý các hóa đơn có cấu trúc cực kỳ phức tạp hoặc bị mờ nhòe nghiêm trọng.

---

## 2.2. LÝ THUYẾT VỀ PHÂN HỆ HIỂU NGÔN NGỮ TỰ NHIÊN (NLU)

Phân hệ NLU chịu trách nhiệm phân loại ý định (Intent Classification) và nhận dạng thực thể (Named Entity Recognition - NER) từ câu thoại tiếng Việt của người dùng.

### 2.2.1. Mô hình ngôn ngữ PhoBERT & Mã hóa đặc trưng (Sentence Encoding)
Mô hình **PhoBERT** phát triển trên kiến trúc RoBERTa cải tiến, được tiền huấn luyện trên kho dữ liệu tiếng Việt quy mô lớn với phương pháp Masked Language Modeling [5].
Để biểu diễn ngữ nghĩa câu thoại $S = \{t_1, t_2, ..., t_n\}$, PhoBERT mã hóa chuỗi ký tự thành các token biểu diễn không gian ẩn. Token đặc biệt đầu tiên đại diện cho toàn bộ câu (`<s>` hoặc `[CLS]`). Trạng thái ẩn đầu ra của token này:
$$\mathbf{h}_{\text{CLS}} \in \mathbb{R}^{768}$$
chứa đựng thông tin tóm tắt toàn bộ bối cảnh ngữ nghĩa của câu chat.

Để tối ưu hóa thời gian suy luận và dung lượng bộ nhớ RAM trên máy chủ, hệ thống áp dụng phương pháp đóng băng (freeze) các tầng Transformer của PhoBERT và trích xuất vector đặc trưng $\mathbf{h}_{\text{CLS}}$. Vector này được đưa vào mô hình phân loại tuyến tính **Logistic Regression** kết hợp bộ hiệu chỉnh xác suất **CalibratedClassifierCV** (sử dụng phương pháp hiệu chỉnh Platt - Platt Scaling) [6].
Hàm Sigmoid được áp dụng để đưa đầu ra quyết định về dạng phân phối xác suất thực tế đáng tin cậy:
$$P(y = c \mid \mathbf{h}_{\text{CLS}}) = \frac{1}{1 + e^{-(A \cdot f(\mathbf{h}_{\text{CLS}}) + B)}}$$
Trong đó $f(\mathbf{h}_{\text{CLS}})$ là điểm số phân loại thô từ mô hình tuyến tính, $A$ và $B$ là các tham số được tối ưu hóa qua tập kiểm thử chéo.

### 2.2.2. Cơ chế lưu trữ và phục hồi mô hình (Joblib Serialization)
Trong môi trường Production, các mô hình học máy (như bộ trích xuất đặc trưng TF-IDF, mô hình phân loại Logistic Regression) cần được lưu trữ dưới dạng nhị phân để phục vụ suy luận nhanh. Thư viện **Joblib** được lựa chọn thay thế cho Pickle truyền thống nhờ cơ chế tối ưu hóa xử lý các mảng dữ liệu NumPy lớn [7].
Joblib thực hiện ghi tuần tự dữ liệu mảng (serialization) bằng cách ghi trực tiếp các vùng nhớ đệm nhị phân (memory mapping) vào đĩa cứng:
$$\text{Serialized State} = \text{joblib.dump}(\mathcal{M}, \text{filepath})$$
Khi tải mô hình lên RAM (deserialization) trong quá trình khởi chạy FastAPI, Joblib sử dụng cơ chế đọc tệp lười (lazy loading) và ánh xạ bộ nhớ (`mmap_mode='r'`), cho phép nhiều luồng xử lý (process workers) chia sẻ chung một vùng nhớ vật lý lưu weights của mô hình, giúp tiết kiệm tối đa RAM và giảm thời gian khởi động server từ vài chục giây xuống dưới 1 giây.

### 2.2.3. Nhận dạng thực thể chi tiêu bằng SpaCy NER
Sau khi xác định câu thoại thuộc intent ghi chép giao dịch (`Record`), hệ thống trích xuất các biến số tài chính thông qua mạng NER của **SpaCy** [8]. Mạng NER này hoạt động theo kiến trúc mạng thần kinh chuyển đổi trạng thái (Transition-based parser).
Tại mỗi trạng thái cấu hình của bộ phân tích, mô hình duy trì ba thành phần toán học:
1. **Stack**: Lưu trữ các token đang được ghép thực thể tích cực.
2. **Buffer**: Lưu trữ các token chưa xử lý tiếp theo trong câu.
3. **Action Set**: Các quyết định chuyển trạng thái bao gồm:
   - $\text{SHIFT}$: Đẩy token đầu tiên trong Buffer vào Stack.
   - $\text{REDUCE}$: Đóng thực thể hiện tại trong Stack và gán nhãn thực thể (`AMOUNT`, `TIME`, `PRODUCT`, `CATEGORY`).
   - $\text{OUT}$: Loại bỏ token nhiễu không có giá trị thông tin tài chính khỏi Buffer.

---

## 2.3. LÝ THUYẾT VỀ PHÂN HỆ NHẬN DẠNG KÝ TỰ QUANG HỌC (OCR)

Phân hệ OCR biến đổi ảnh chụp hóa đơn thành dữ liệu số có cấu trúc qua quy trình phát hiện và nhận dạng dòng chữ.

### 2.3.1. Phát hiện chữ bằng mạng DBNet
Thuật toán **DBNet (Differentiable Binarization Network)** giải quyết bài toán phát hiện văn bản dạng đa giác tự do bằng cách nhị phân hóa khả vi trực tiếp trong quá trình huấn luyện mạng [9].

```
                     ┌──► Probability Map (P) ──┐
                     │                          │
[Feature Pyramid] ───┼                          ├──► Approximate Binarization (B̂)
                     │                          │
                     └──► Threshold Map (T) ────┘
```

Trong các mạng phát hiện truyền thống, phép toán nhị phân hóa cứng (Hard Thresholding) được thực hiện để tìm biên chữ:
$$B_{i,j} = \begin{cases} 1 & \text{nếu } P_{i,j} \ge t \\ 0 & \text{ngược lại} \end{cases}$$
Hàm này có đạo hàm bằng 0 ở mọi nơi và không liên tục tại điểm $t$, do đó không thể tối ưu hóa trực tiếp bằng phương pháp lan truyền ngược (backpropagation). DBNet thay thế bằng hàm nhị phân hóa mềm khả vi (Approximate Binarization):
$$\hat{B}_{i,j} = \frac{1}{1 + e^{-k(P_{i,j} - T_{i,j})}}$$
Trong đó:
- $P_{i,j}$ là bản đồ xác suất (Probability Map) dự đoán một điểm ảnh thuộc vùng lõi chữ.
- $T_{i,j}$ là bản đồ ngưỡng thích ứng (Threshold Map) học từ mạng để xác định biên giới hạn chữ.
- $k$ là hệ số dốc (amplifier factor), được chọn mặc định bằng 50 để xấp xỉ hóa hàm bước nhảy.

Hàm mất mát đa mục tiêu (Multi-task Loss Function) để huấn luyện DBNet:
$$\mathcal{L} = \mathcal{L}_s(P, Y) + \alpha \mathcal{L}_b(\hat{B}, Y) + \beta \mathcal{L}_t(T, G)$$
Trong đó:
- $\mathcal{L}_s$ là hàm mất mát entropy chéo có trọng số (weighted binary cross-entropy) giữa bản đồ xác suất $P$ và nhãn vùng lõi chữ $Y$.
- $\mathcal{L}_b$ là hàm mất mát $L_1$ giữa bản đồ nhị phân khả vi $\hat{B}$ và nhãn gốc $Y$.
- $\mathcal{L}_t$ là hàm mất mát $L_1$ giữa bản đồ ngưỡng $T$ và bản đồ biên chữ thực tế $G$.
- $\alpha, \beta$ là các hệ số cân bằng trọng số (mặc định $\alpha = 1.0, \beta = 10.0$).

### 2.3.2. Hiệu chỉnh hướng ảnh bằng MobileNetV3
Nhằm giảm thiểu sai sót nhận diện khi hóa đơn bị chụp ngược (xoay 90°, 180°, 270°), mô hình phân loại hướng sử dụng kiến trúc **MobileNetV3** gọn nhẹ [10]. Mô hình ứng dụng phép tích chập phân tách chiều sâu (Depthwise Separable Convolution) để tiết kiệm tài nguyên.
Phép tích chập thông thường kích thước $D_K \times D_K \times M \times N$ được tách thành:
1. **Depthwise Convolution**: Một bộ lọc kích thước $D_K \times D_K \times 1$ cho mỗi kênh trong số $M$ kênh đầu vào.
2. **Pointwise Convolution**: Tích chập kích thước $1 \times 1 \times M \times N$ để tổng hợp tuyến tính thông tin giữa các kênh.

Tỷ lệ tiết kiệm chi phí tính toán:
$$\text{Ratio} = \frac{D_K \times D_K \times M + M \times N}{D_K \times D_K \times M \times N} = \frac{1}{N} + \frac{1}{D_K^2}$$
Với bộ lọc $3 \times 3$ ($D_K = 3$), lượng tính toán giảm đi xấp xỉ 9 lần, giúp mô hình hoạt động cực kỳ nhanh trên CPU của máy chủ AI.

### 2.3.3. Nhận dạng chữ viết tiếng Việt bằng VietOCR (VGG + BiLSTM + Attention)
Mô hình **VietOCR** kế thừa kiến trúc CRNN (Convolutional Recurrent Neural Network) nhưng thay thế bộ giải mã CTC bằng bộ giải mã Attention nhằm nâng cao độ chính xác nhận diện nguyên âm tiếng Việt có dấu phức tạp [11].

1. **Feature Extraction (VGG19-BN)**: Trích xuất đặc trưng vùng ảnh chữ kích thước $H \times W \times C$ thành bản đồ đặc trưng có kích thước $1 \times W' \times D$.
2. **Context Modeling (BiLSTM)**: Chuỗi vector đặc trưng được đưa qua mạng LSTM hai chiều để ghi nhận ngữ cảnh ký tự trước và sau trong từ.
3. **Bahdanau Attention Decoder**: Mạng GRU giải mã kết hợp cơ chế chú ý Bahdanau. Tại mỗi bước giải mã $i$, mô hình tính toán trọng số chú ý $\alpha_{i,j}$ của trạng thái ẩn decoder $s_{i-1}$ trên toàn bộ các vector đặc trưng encoder $h_j$:
   $$e_{i,j} = v_a^T \tanh(W_a s_{i-1} + U_a h_j)$$
   $$\alpha_{i,j} = \frac{\exp(e_{i,j})}{\sum_{k=1}^{T_x} \exp(e_{i,k})}$$
   Vector ngữ cảnh tích hợp $c_i$ được tính bằng tổng có trọng số:
   $$c_i = \sum_{j=1}^{T_x} \alpha_{i,j} h_j$$
   GRU decoder sử dụng $c_i$ và ký tự dự đoán ở bước trước để sinh ra ký tự tiếp theo, giúp giảm thiểu hiện tượng mất dấu tiếng Việt thường gặp ở các mô hình OCR thông thường.

---

## 2.4. LÝ THUYẾT VỀ KIẾN TRÚC DỮ LIỆU PHÂN TÁN & LƯU TRỮ ĐÁM MÂY

Để đảm bảo tính nhất quán của số liệu tài chính và khả năng mở rộng hệ thống, MoneyStory triển khai kiến trúc cơ sở dữ liệu phân tán kết hợp lưu trữ đám mây.

### 2.4.1. Cơ sở dữ liệu phân tán CockroachDB & Đồng thuận Raft
Hệ thống sử dụng **CockroachDB**, một hệ quản trị cơ sở dữ liệu quan hệ SQL phân tán (Distributed SQL), hỗ trợ tính năng ACID toàn cục (Global ACID transactions) [12].
CockroachDB tổ chức lưu trữ dữ liệu dưới dạng các cặp khóa - giá trị (Key-Value pairs) phân rã thành các phân vùng gọi là Ranges (mỗi range có kích thước mặc định 64MB). Để đảm bảo tính sẵn sàng cao và khả năng chống lỗi chịu tải, mỗi Range được nhân bản ra ít nhất 3 nodes vật lý thông qua giải thuật đồng thuận **Raft Consensus Protocol**.

Trong giải thuật Raft:
- Mỗi Range có một Node đóng vai trò là **Raft Leader** (chịu trách nhiệm nhận yêu cầu ghi dữ liệu) và các Nodes đóng vai trò **Raft Followers**.
- Khi có một giao dịch thêm mới chi tiêu phát sinh từ Backend Node.js, Raft Leader nhận yêu cầu ghi, ghi vào nhật ký cục bộ (Write-Ahead Log) và gửi bản sao nhật ký đến các Followers.
- Giao dịch chỉ được cam kết chính thức (committed) ghi vào cơ sở dữ liệu khi nhận được xác nhận đồng ý từ đa số thành viên trong nhóm đồng thuận (Quorum):
  $$\text{Quorum} = \lfloor N/2 \rfloor + 1$$
  Với $N = 3$, hệ thống cần tối thiểu 2 nodes đồng ý. Cơ chế này đảm bảo dữ liệu giao dịch chi tiêu của người dùng luôn nhất quán và không bao giờ bị mất ngay cả khi một máy chủ database cloud bị sập đột ngột.

### 2.4.2. Lưu trữ đối tượng đám mây Cloudflare R2
Hình ảnh hóa đơn và tệp âm thanh thô của người dùng được lưu trữ trên **Cloudflare R2** - hệ thống lưu trữ đối tượng (Object Storage) không tính phí băng thông truyền tải dữ liệu ra ngoài (zero egress fees), tương thích hoàn toàn với giao thức AWS S3 API [13].

Để bảo đảm tính riêng tư và an toàn dữ liệu tài chính, ứng dụng di động không tải ảnh trực tiếp lên các thư mục công khai. Backend Node.js thiết lập quy trình bảo mật qua cơ chế **Presigned URL**:
1. Client gửi yêu cầu tải ảnh lên kèm thông tin tệp.
2. Backend gọi thư viện `@aws-sdk/s3-request-presigner` để sinh ra một đường dẫn tải lên tạm thời có chữ ký số mã hóa đối xứng (HMAC-SHA256) chứa các thông tin giới hạn quyền truy cập:
   $$\text{Signature} = \text{HMAC-SHA256}(\text{SecretKey}, \text{Method} + \text{Bucket} + \text{Key} + \text{Expires})$$
3. Client nhận Presigned URL, thực hiện tải ảnh trực tiếp lên Cloudflare R2. Đường dẫn này chỉ có hiệu lực trong một khoảng thời gian ngắn (mặc định 15 phút), giúp ngăn ngừa việc rò rỉ dữ liệu hóa đơn của người dùng ra môi trường internet công cộng.

---

## TÀI LIỆU THAM KHẢO (BIBLIOGRAPHY)

[1] N. D. Cuong, M. P. Hoang, et al., **"MC-OCR Challenge 2021: End-to-end system to extract key information from Vietnamese Receipts,"** in *Proceedings of the 2021 IEEE RIVF International Conference on Computing and Communication Technologies (RIVF)*, 2021, pp. 1-6. DOI: [10.1109/RIVF51545.2021.9642083](https://doi.org/10.1109/RIVF51545.2021.9642083).

[2] Yu, M., Li, Y., et al., **"PICK: Processing Key Information Extraction from Documents using Improved Graph Relation Networks,"** in *Proceedings of the 28th International Conference on Computational Linguistics (COLING)*, 2020, pp. 4363–4373. arXiv: [2004.07464](https://arxiv.org/abs/2004.07464).

[3] Huang, Y., Lv, T., et al., **"LayoutLMv3: Pre-training for Document AI with Unified Text and Image Masking,"** in *Proceedings of the 30th ACM International Conference on Multimedia (MM)*, 2022, pp. 4083-4091. DOI: [10.1145/3503161.3548112](https://doi.org/10.1145/3503161.3548112).

[4] Bai, J., Yang, S., et al., **"Qwen-VL: A Versatile Vision-Language Model for Understanding, Localization, Text Reading, and Beyond,"** *arXiv preprint arXiv:2308.12966*, 2023. arXiv: [2308.12966](https://arxiv.org/abs/2308.12966).

[5] Nguyen, D. Q., and T. Nguyen, **"PhoBERT: Pre-trained language models for Vietnamese,"** in *Findings of the Association for Computational Linguistics: EMNLP 2020*, 2020, pp. 1037-1042. DOI: [10.18653/v1/2020.findings-emnlp.92](https://doi.org/10.18653/v1/2020.findings-emnlp.92).

[6] Niculescu-Mizil, A., and R. Caruana, **"Predicting good probabilities with supervised learning,"** in *Proceedings of the 22nd International Conference on Machine Learning (ICML)*, 2005, pp. 625-632. DOI: [10.1145/1102351.1102430](https://doi.org/10.1145/1102351.1102430).

[7] Pedregosa, F., Varoquaux, G., et al., **"Scikit-learn: Machine learning in Python,"** *Journal of Machine Learning Research (JMLR)*, vol. 12, pp. 2825-2830, 2011.

[8] Honnibal, M., and I. Montani, **"spaCy 2: Natural language understanding with Bloom embeddings, convolutional neural networks and incremental parsing,"** *Sentient NLP*, vol. 7, no. 1, pp. 411-420, 2017.

[9] Liao, M., Wan, Z., et al., **"Real-time Scene Text Detection with Differentiable Binarization,"** in *Proceedings of the AAAI Conference on Artificial Intelligence*, vol. 34, no. 07, 2020, pp. 11474-11481. DOI: [10.1609/aaai.v34i07.6812](https://doi.org/10.1609/aaai.v34i07.6812).

[10] Howard, A., Sandler, M., et al., **"Searching for MobileNetV3,"** in *Proceedings of the IEEE/CVF International Conference on Computer Vision (ICCV)*, 2019, pp. 1314-1324. DOI: [10.1109/ICCV.2019.00140](https://doi.org/10.1109/ICCV.2019.00140).

[11] Bahdanau, D., Cho, K., and Y. Bengio, **"Neural machine translation by jointly learning to align and translate,"** in *3rd International Conference on Learning Representations (ICLR)*, 2015, pp. 1-15. arXiv: [1409.0473](https://arxiv.org/abs/1409.0473).

[12] Taft, R., Sharif, U., et al., **"CockroachDB: The Resilient Geo-Distributed SQL Database,"** in *Proceedings of the 2020 ACM SIGMOD International Conference on Management of Data*, 2020, pp. 1493-1509. DOI: [10.1145/3318464.3386134](https://doi.org/10.1145/3318464.3386134).

[13] Cloudflare, **"R2 Object Storage: S3-compatible, zero-egress object storage,"** Cloudflare Docs, 2022. [Online]. Available: https://developers.cloudflare.com/r2/.
