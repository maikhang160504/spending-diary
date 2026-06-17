# BÁO CÁO BRAINSTORM CHIẾT XUẤT HÓA ĐƠN & PHÂN LOẠI CHI TIÊU HỆ THỐNG FINTECH
**Dự án:** Hệ thống quản lý chi tiêu cá nhân dạng Story (Luồng Bill-Only)
**Vai trò:** Giám đốc Công nghệ (CTO) & Kiến trúc sư trưởng Hệ thống AI (Principal AI Architect)

---

## MỞ ĐẦU
Trong luồng vận hành **Bill-Only** (người dùng chỉ chụp ảnh hóa đơn, không nhập văn bản bổ trợ), hệ thống xử lý bất đồng bộ qua Worker ngầm và đẩy kết quả qua WebSocket. Mọi sai sót từ OCR sẽ trực tiếp làm giảm trải nghiệm người dùng cuối. Tài liệu này cung cấp các giải pháp tối ưu hóa sâu sắc cho 6 vấn đề cốt lõi của hệ thống xử lý hóa đơn tự động.

---

## VẤN ĐỀ 1: SAI LỆCH SỐ TIỀN DO CÁC DÒNG THANH TOÁN PHỤ (VAT, CHIẾT KHẤU, TIỀN MẶT, TIỀN THỐI)

### 1. Phân tích kỹ thuật (Technical Deep Dive)
Các thuật toán trích xuất số tiền truyền thống thường áp dụng bộ lọc heuristics đơn giản như "tìm số lớn nhất" (`max(amounts)`) hoặc chỉ quét tìm từ khóa chứa `"Tổng"` rồi lấy số đi sau. Cách tiếp cận này thất bại ở các trường hợp sau:
* **Tiền khách đưa (Cash Received) / Tiền thối lại (Change):** Dòng này thường xuất hiện dưới cùng của hóa đơn và mang giá trị lớn (ví dụ: khách đưa tờ $500.000$ cho đơn hàng $150.000$). Khi đó `max(amounts)` sẽ nhận nhầm số tiền chi tiêu là $500.000$.
* **Chiết khấu / Thuế VAT:** Các số tiền trung gian (Tổng trước thuế, Tiền chiết khấu, Tiền thuế VAT) đứng sát cạnh nhau. Nếu chỉ dùng Regex tìm số cạnh từ khóa, hệ thống dễ bị bắt nhầm các con số trung gian này.
* **Hóa đơn in chéo/lệch cột:** Khoảng cách giữa nhãn chữ `"Tổng thanh toán"` và số tiền `$148.500$` quá rộng khiến thuật toán gom dòng ngang thô sơ bị gãy, ghép số tiền của dòng dưới (ví dụ `"Tiền mặt: 500.000"`) vào dòng tổng.

### 2. Biện pháp Tối ưu ngắn hạn (Quick Wins)
Can thiệp trực tiếp bằng cách thiết kế bộ lọc Regex hai tầng kết hợp cấu trúc dữ liệu loại trừ:
* **Tầng 1: Lọc bỏ dòng phi tài chính (Negation / Exclude Patterns):** Quét qua từng dòng văn bản và loại bỏ các dòng chứa từ khóa chỉ tiền khách đưa (`tiền mặt`, `khách đưa`, `cash`, `received`) hoặc tiền thối (`tiền thừa`, `thối lại`, `change`, `cash return`).
* **Tầng 2: Điểm ưu tiên từ khóa (Weighted Keyword Matching):** Gán trọng số điểm cho các từ khóa tổng tiền thực chi. Dòng nào khớp từ khóa có trọng số cao nhất (ví dụ: `tổng thanh toán`, `momo`, `chuyển khoản`, `thực thu`) sẽ được ưu tiên bóc tách số tiền.
* **Tầng 3: Đối chiếu ràng buộc số dư:** Nếu bóc được cả dòng `"Tổng tiền hàng"`, `"Chiết khấu"`, `"VAT"`, và `"Tổng thanh toán"`, áp dụng kiểm tra logic toán học:
  $$\text{Tổng thanh toán} = \text{Tổng tiền hàng} + \text{VAT} - \text{Chiết khấu}$$

### 3. Biện pháp Tối ưu dài hạn (Scalable Solutions)
* **LayoutLMv3 / Donut (Document Understanding Transformer):** Huấn luyện mô hình đa phương thức (Multimodal AI) kết hợp cả Text, Vị trí (Layout Bounding Box), và Ảnh (Vision). Mô hình học cách liên kết khóa-giá trị (Key-Value Relation Extraction) để trỏ thẳng từ khóa `"Tổng cộng"` vào đúng bounding box của số tiền thanh toán thực tế, thay vì xử lý heuristic.
* **Biểu đồ quan hệ thực thể (Graph Neural Networks - GNNs):** Biểu diễn hóa đơn dưới dạng một đồ thị, trong đó mỗi bounding box là một nút, và các cạnh biểu thị khoảng cách hình học. GNNs sẽ phân loại nút tổng tiền dựa trên cấu trúc hình học của hóa đơn (thường nằm ở góc phải chân trang).

### 4. Mã giả minh họa (Pseudo-code)
```python
import re
from typing import List, Dict, Any, Optional

# Regex loại trừ các số tiền phụ đại diện cho tiền khách đưa hoặc tiền thối lại
RE_EXCLUDE_LINE = re.compile(
    r"tien\s*mat|khach\s*dua|tien\s*khach|cash|received|tra\s*lai|tien\s*thua|thoi\s*lai|change|khach\s*tra", 
    re.I
)

# Trọng số ưu tiên từ khóa tổng tiền thực tế
TOTAL_KEYWORDS_WEIGHTS = [
    (100, re.compile(r"tong\s*thanh\s*toan|thuc\s*thu|thuc\s*tra|phai\s*thanh\s*toan|thanh\s*toan\s*momo|chuyen\s*khoan", re.I)),
    (90, re.compile(r"tong\s*cong|thanh\s*tien|total\s*due|amount\s*due", re.I)),
    (70, re.compile(r"tong\s*tien|total\s*amount|total", re.I)),
    (50, re.compile(r"cong\s*tien\s*hang|tien\s*hang", re.I))
]

def parse_currency(text: str) -> Optional[int]:
    """Trích xuất và chuẩn hóa số nguyên từ chuỗi tiền tệ."""
    digits = re.sub(r"\D", "", text)
    return int(digits) if digits else None

def extract_exact_total_amount(ocr_lines: List[Dict[str, Any]]) -> Optional[int]:
    """
    ocr_lines: List các dòng chứa {"text": str, "bbox": [x1, y1, x2, y2]}
    Trả về số tiền thực chi chính xác nhất.
    """
    candidates = []
    
    # Duyệt ngược từ dưới lên (Footer thường chứa tổng tiền)
    for idx, line in enumerate(reversed(ocr_lines)):
        text_clean = line["text"].strip()
        
        # Tìm tất cả các số tiền tiềm năng trong dòng
        amount_tokens = re.findall(r"\b\d{1,3}(?:[.,]\d{3})+\b|\b\d{4,9}\b", text_clean)
        if not amount_tokens:
            continue
            
        # Kiểm tra nếu dòng chứa từ khóa loại trừ
        if RE_EXCLUDE_LINE.search(text_clean):
            continue
            
        # Đánh giá trọng số từ khóa tổng cộng
        for weight, pattern in TOTAL_KEYWORDS_WEIGHTS:
            if pattern.search(text_clean):
                val = parse_currency(amount_tokens[-1]) # Lấy số cuối cùng trên dòng
                if val and 1000 <= val <= 50000000:
                    candidates.append((weight, idx, val))
                    break
                    
    if candidates:
        # Sắp xếp theo trọng số giảm dần, và theo vị trí gần cuối hóa đơn (idx nhỏ)
        candidates.sort(key=lambda x: (-x[0], x[1]))
        return candidates[0][2]
        
    # Fallback: Nếu không tìm thấy từ khóa, lấy giá trị lớn nhất từ các dòng không bị loại trừ
    all_numbers = []
    for line in ocr_lines:
        text_clean = line["text"].strip()
        if RE_EXCLUDE_LINE.search(text_clean):
            continue
        tokens = re.findall(r"\b\d{1,3}(?:[.,]\d{3})+\b|\b\d{4,9}\b", text_clean)
        for t in tokens:
            val = parse_currency(t)
            if val and 1000 <= val <= 50000000:
                all_numbers.append(val)
                
    return max(all_numbers) if all_numbers else None
```

---

## VẤN ĐỀ 2: SAI LỆCH DANH MỤC DO HÓA ĐƠN SIÊU THỊ/CỬA HÀNG TIỆN LỢI (MIXED-CATEGORY RECEIPTS)

### 1. Phân tích kỹ thuật (Technical Deep Dive)
Hệ thống hiện tại ném toàn bộ khối văn bản thô của hóa đơn vào mô hình TF-IDF + SVM để dự đoán một nhãn duy nhất. Phương pháp này thất bại ở các hóa đơn hỗn hợp (Mixed-Category) từ siêu thị hoặc cửa hàng tiện lợi vì:
* **Sự lấn át của nhóm sản phẩm:** Nếu giỏ hàng có 5 chai nước ngọt (Food) và 1 tuýp kem đánh răng (Essentials), SVM sẽ dự đoán nhãn chung là `Food` do mật độ từ khóa `Food` quá cao. Khoản tiền chi cho `Essentials` bị biến mất hoàn toàn trong thống kê chi tiêu.
* **Đặc trưng từ rác làm nhiễu:** Văn bản thô chứa tên siêu thị (ví dụ `"WINMART"`), thông tin khuyến mãi, địa chỉ sẽ khiến SVM có xu hướng phân loại nhãn tổng quát hoặc bị lệch sang nhãn mặc định `Others`.

### 2. Biện pháp Tối ưu ngắn hạn (Quick Wins)
* **Item-Level Classification:** Không đưa toàn bộ văn bản thô vào SVM. Thay vào đó, trích xuất riêng lẻ từng dòng mặt hàng (`item line`), chỉ gửi chuỗi tên mặt hàng thô (ví dụ: `"Kem danh rang Colgate"`) qua SVM để lấy danh mục và xác suất tin cậy (`confidence`).
* **Weighted Voting by Value (Bỏ phiếu trọng số theo giá trị tiền):** 
  Nếu cấu hình hệ thống chỉ cho phép trả về một danh mục duy nhất (`SPLIT_MODE = False`), tính điểm bỏ phiếu cho từng danh mục dựa trên số tiền chi cho món hàng đó:
  $$\text{Score}(Category_c) = \sum_{i \in \text{Items of } c} \text{Price}_i \times \text{Confidence}_i$$
  Chọn danh mục có điểm cao nhất làm danh mục đại diện.
* **Many-to-One Database Splitting (Tách giao dịch tự động):**
  Nếu `SPLIT_MODE = True`, gom nhóm các món hàng có cùng danh mục dự đoán lại, tính tổng tiền cho mỗi nhóm, và lưu thành nhiều bản ghi giao dịch con trong bảng `transactions` liên kết chung với một `story_item_id` của ảnh hóa đơn.

### 3. Biện pháp Tối ưu dài hạn (Scalable Solutions)
* **Chuyển đổi sang Mô hình ngôn ngữ lớn (Local LLM - Llama 3/Mistral/Qwen):**
  Chạy một mô hình LLM siêu nhẹ (ví dụ `Qwen-2.5-7B-Instruct` hoặc `Llama-3-8B` lượng tử hóa 4-bit) trên GPU Worker. Đưa toàn bộ danh sách mặt hàng đã nhận diện vào prompt. LLM sẽ trả về cấu trúc JSON phân loại danh mục chính xác cho từng mặt hàng nhờ vào khả năng hiểu ngữ nghĩa thế giới thực vượt trội so với SVM.
* **Hierarchical Classification Network (Mạng phân loại phân cấp):**
  Xây dựng pipeline phân loại 2 lớp. Lớp 1 phân loại xem hóa đơn có phải là hóa đơn đa ngành (General Supermarket) hay không. Nếu có, kích hoạt module bóc tách dòng hàng (Segmenter). Nếu không, trực tiếp gán nhãn qua Brand Routing để tiết kiệm tài nguyên.

### 4. Mã giả minh họa (Pseudo-code)
```python
from typing import List, Dict, Any, Tuple

def resolve_mixed_receipt_categories(
    items: List[Tuple[str, int]], # List các tuple: (tên_món_hàng, thành_tiền)
    predict_svm_fn,               # Hàm dự đoán SVM hiện có: fn(text) -> (category, conf)
    split_mode: bool = True,
    entropy_threshold: float = 0.65
) -> List[Dict[str, Any]]:
    """
    Phân loại và phân bổ danh mục cho hóa đơn hỗn hợp.
    Trả về danh sách các giao dịch cần lưu vào PostgreSQL.
    """
    if not items:
        return [{"category_id": "Others", "amount": 0}]
        
    category_totals = {}
    
    # Bước 1: Phân loại độc lập từng món hàng và cộng dồn tiền theo danh mục
    for name, price in items:
        category, confidence = predict_svm_fn(name)
        
        # Nếu độ tin cậy quá thấp, đưa vào Others để tránh gán nhầm
        cat_label = category if confidence >= 0.60 else "Others"
        
        if cat_label not in category_totals:
            category_totals[cat_label] = 0
        category_totals[cat_label] += price
        
    total_bill_amount = sum(price for _, price in items)
    
    # Bước 2: Ra quyết định tạo giao dịch
    if split_mode:
        # Giải pháp Tách giao dịch con (Many-to-One)
        transactions = []
        for cat, amt in category_totals.items():
            transactions.append({
                "category": cat,
                "amount": amt,
                "note": f"Tự động tách từ hóa đơn gốc ({int(amt/total_bill_amount*100)}%)"
            })
        return transactions
    else:
        # Giải pháp Bỏ phiếu trọng số để tìm 1 danh mục đại diện duy nhất
        primary_category = max(category_totals, key=category_totals.get)
        primary_amount = category_totals[primary_category]
        
        # Kiểm tra tỷ lệ thống trị
        dominance_ratio = primary_amount / total_bill_amount
        if dominance_ratio >= entropy_threshold:
            return [{"category": primary_category, "amount": total_bill_amount}]
        else:
            # Nếu phân tán quá rộng, fallback về Essentials (Đi chợ/Thiết yếu)
            return [{
                "category": "Essentials", 
                "amount": total_bill_amount, 
                "note": "Hóa đơn siêu thị hỗn hợp nhiều mặt hàng"
            }]
```

---

## VẤN ĐỀ 3: SAI LỆCH DANH MỤC DO THƯƠNG HIỆU/CỬA HÀNG LẠ (UNSEEN MERCHANTS) & TÊN VIẾT TẮT

### 1. Phân tích kỹ thuật (Technical Deep Dive)
Các hóa đơn từ tạp hóa nhỏ lẻ, tiệm bánh tự phát hoặc viết tắt tên thương hiệu (ví dụ `"T.HOA CO NAM"`, `"TIEM BANH ML"`) khiến mô hình TF-IDF + SVM bị mất phương hướng. Lý do:
* **Tỷ lệ từ Out-Of-Vocabulary (OOV) cao:** Bộ từ điển TF-IDF được huấn luyện trên tập dữ liệu chuẩn hóa sẽ gán trọng số bằng 0 hoặc rất nhỏ cho các từ viết tắt hoặc tên riêng lạ. Mô hình sẽ dự đoán nhầm hoặc đẩy về lớp mặc định `Others`.
* **Không có text bổ trợ:** Luồng Bill-Only không cho phép người dùng nhập mô tả ngữ cảnh (ví dụ: *"Ăn bánh ngọt"*), làm mất đi nguồn thông tin cực kỳ quan trọng để định vị danh mục.

### 2. Biện pháp Tối ưu ngắn hạn (Quick Wins)
Triển khai bộ giải pháp phân lớp xử lý (Multi-tier Resolution Engine):
* **Lớp 1: Bảng định tuyến thương hiệu (Brand Routing Database):**
  Lưu trữ bảng `brand_routing` trong PostgreSQL chứa tên các chuỗi thương hiệu phổ biến viết tắt và danh mục cố định (ví dụ: `HIGHLANDS` / `PLONG` $\rightarrow$ `Food`).
* **Lớp 2: Từ điển chuẩn hóa tên viết tắt siêu thị (Abbreviation Regex Mapping):**
  Trước khi đưa text vào SVM, chạy qua bộ ánh xạ Regex để khôi phục ngữ nghĩa thô:
  * `BM` / `B.M` $\rightarrow$ `banh mi` (Food)
  * `K.UOT` / `KHAN UOT` $\rightarrow$ `khan uot` (Essentials)
* **Lớp 3: Character-level N-gram TF-IDF:**
  Cấu hình bộ tiền xử lý TF-IDF của SVM sử dụng Character n-gram ($n \in [3, 4, 5]$). Điều này giúp bảo toàn ngữ nghĩa của các từ viết tắt bị mất nguyên âm (ví dụ `"KHAN UOT"` vẫn chứa các mảnh ký tự tương tự như `"khăn ướt"` và được phân loại đúng vào `Essentials`).
* **Lớp 4: Vòng lặp phản hồi người dùng (User Feedback Cache):**
  Khi người dùng sửa tay danh mục hóa đơn từ một quán lạ, lưu cặp `(tên_quán, danh_mục_sửa)` vào PostgreSQL. Lần sau nếu gặp lại đúng tên quán này, hệ thống sẽ tự động ghi đè danh mục mà không cần chạy SVM.

### 3. Biện pháp Tối ưu dài hạn (Scalable Solutions)
* **Tích hợp API Địa điểm (Google Maps / Yelp / OpenStreetMap API):**
  Trích xuất tọa độ GPS từ EXIF metadata của ảnh hóa đơn (hoặc vị trí GPS của điện thoại lúc upload bill) kết hợp với địa chỉ/tên cửa hàng bóc được từ OCR. Gửi request tìm kiếm địa điểm lân cận để lấy trường `type` (ví dụ: `bakery` $\rightarrow$ `Food`, `pharmacy` $\rightarrow$ `Health`).
* **Vector Semantic Search (RAG với Vector DB):**
  Chuyển đổi tên cửa hàng và danh sách mặt hàng thành vector nhúng (Embedding Vector) bằng mô hình như `Sentence-BERT` tiếng Việt. Thực hiện tìm kiếm tương đồng (Cosine Similarity) trên Vector Database chứa danh mục hàng triệu sản phẩm tiêu dùng đã được gán nhãn trước.

### 4. Mã giả minh họa (Pseudo-code)
```python
import re
from typing import Dict, Tuple, Optional

# Từ điển ánh xạ từ viết tắt thô sơ của siêu thị thành từ chuẩn hóa
ABBREVIATIONS_MAP = {
    r"\bb\.m\b|\bbm\b": "banh mi",
    r"\bg\.vi\b|\bgia\s*vi\b": "gia vi",
    r"\bk\.uot\b|\bk\s*uot\b": "khan uot",
    r"\bt\.hoa\b|\btap\s*hoa\b": "tap hoa",
    r"\bkem\s*d\.rang\b": "kem danh rang"
}

def preprocess_abbreviations(text: str) -> str:
    """Thay thế các từ viết tắt dựa trên từ điển regex."""
    text_lower = text.lower()
    for pattern, replacement in ABBREVIATIONS_MAP.items():
        text_lower = re.sub(pattern, replacement, text_lower)
    return text_lower

def resolve_unseen_merchant_category(
    merchant_name: str,
    db_conn, # Kết nối PostgreSQL
    predict_svm_fn
) -> str:
    """
    Quyết định danh mục cho quán lạ/viết tắt qua 3 tầng bảo vệ.
    """
    merchant_clean = preprocess_abbreviations(merchant_name.strip())
    
    # Tầng 1: Tra cứu phản hồi lịch sử (User Feedback Cache) trong DB
    cursor = db_conn.cursor()
    cursor.execute(
        "SELECT corrected_category FROM user_feedback_merchants WHERE merchant_name = %s LIMIT 1",
        (merchant_clean,)
    )
    db_row = cursor.fetchone()
    if db_row:
        return db_row[0]
        
    # Tầng 2: Tra cứu bảng Brand Routing tĩnh cho chuỗi thương hiệu phổ biến
    cursor.execute(
        "SELECT category FROM brand_routing WHERE %s ILIKE CONCAT('%%', brand_name, '%%') LIMIT 1",
        (merchant_clean,)
    )
    brand_row = cursor.fetchone()
    if brand_row:
        return brand_row[0]
        
    # Tầng 3: Chạy mô hình SVM Character-level N-gram Fallback
    category, confidence = predict_svm_fn(merchant_clean)
    if confidence >= 0.50:
        return category
        
    return "Others"
```

---

## VẤN ĐỀ 4: LỖI NHẬN DẠNG SỐ TIỀN DO OCR MẤT NÉT (DIGIT DROP/SHIFT / DẤU PHÂN TÁCH)

### 1. Phân tích kỹ thuật (Technical Deep Dive)
Do chất lượng ảnh chụp (rung tay, thiếu sáng, hóa đơn bị mờ nét mực), OCR thường mắc phải các lỗi mất chữ số cực kỳ nghiêm trọng:
* **Digit Drop (Mất số 0 cuối):** Số tiền thanh toán `$120.000$` bị nhận diện thiếu một số 0 ở cuối thành `$12.000$` hoặc `$12.00$`.
* **Digit Shift (Lệch dấu phân tách):** Dấu chấm ngăn cách hàng nghìn bị nhận diện nhầm thành dấu phẩy thập phân hoặc ngược lại khiến số tiền bị chuyển đổi sai kiểu dữ liệu (ví dụ `$150.000$` thành `$150` đồng).
* **Không kiểm chứng chéo:** Hệ thống tin tưởng 100% vào dòng tổng cộng mà không đối chiếu với tổng các dòng mặt hàng phía trên.

### 2. Biện pháp Tối ưu ngắn hạn (Quick Wins)
Xây dựng lớp **Kiểm chéo toán học (Mathematical Cross-Validation)** dựa trên quan hệ giữa các món hàng:
* **Bước 1: Tính tổng toán học của các dòng hàng (Sum of Items):**
  $$\text{Sum\_Items} = \sum (\text{Đơn giá mảng hàng} \times \text{Số lượng})$$
* **Bước 2: Phát hiện sai số tỷ lệ (Scale Detection):**
  So sánh số tiền tổng cộng nhận diện được ($\text{Total\_OCR}$) với $\text{Sum\_Items}$.
  * Nếu $\text{Sum\_Items} \approx 10 \times \text{Total\_OCR}$ (sai lệch < 5%), kết luận dòng tổng bị OCR nuốt mất một số 0. Tự động nhân 10 giá trị $\text{Total\_OCR}$.
  * Nếu $\text{Sum\_Items} \approx \text{Total\_OCR} \times 1000$ (do nhầm dấu phẩy thập phân), tự động nhân 1000 giá trị $\text{Total\_OCR}$.
* **Bước 3: Tự động ghi đè và đánh dấu cảnh báo:**
  Ghi đè số tiền bằng $\text{Sum\_Items}$ và bắn cảnh báo `AMOUNT_CORRECTED_BY_MATH` vào logs để QA giám sát.

### 3. Biện pháp Tối ưu dài hạn (Scalable Solutions)
* **Huấn luyện mô hình sửa lỗi chính tả số (Sequence-to-Sequence Correction):**
  Xây dựng mạng Seq2Seq (như Transformer/GRU) chuyên nhận đầu vào là chuỗi số OCR thô và đầu ra là chuỗi số đã hiệu chỉnh dựa trên phân phối tiền tệ phổ biến và kiểm thử tính nhất quán toán học.
* **Double-pass OCR Validation:**
  Chạy hai mô hình OCR độc lập (ví dụ: PaddleOCR và một mô hình OCR siêu nhẹ khác như EasyOCR). So sánh kết quả số tiền trích xuất của cả hai. Nếu có sự lệch biệt, kích hoạt luồng kiểm tra chéo toán học hoặc đẩy hóa đơn vào hàng đợi xử lý thủ công của WebAdmin.

### 4. Mã giả minh họa (Pseudo-code)
```python
from typing import List, Tuple, Dict, Any

def validate_and_correct_total_amount(
    ocr_total: int, 
    items: List[Tuple[str, int]], 
    tolerance_ratio: float = 0.05
) -> Tuple[int, List[str]]:
    """
    Kiểm chéo số tiền tổng cộng với tổng các mặt hàng để phát hiện lỗi mất nét số 0.
    """
    warnings = []
    if not items:
        return ocr_total, warnings
        
    sum_items = sum(price for _, price in items)
    if sum_items == 0:
        return ocr_total, warnings
        
    # Trường hợp 1: OCR mất số 0 cuối (Lệch 10 lần)
    # Ví dụ: Tổng món hàng = 120.000, OCR đọc được = 12.000
    if abs(sum_items - ocr_total * 10) / sum_items <= tolerance_ratio:
        corrected_total = sum_items
        warnings.append("AMOUNT_CORRECTED_SCALE_10X")
        return corrected_total, warnings
        
    # Trường hợp 2: OCR mất hai số 0 cuối (Lệch 100 lần)
    if abs(sum_items - ocr_total * 100) / sum_items <= tolerance_ratio:
        corrected_total = sum_items
        warnings.append("AMOUNT_CORRECTED_SCALE_100X")
        return corrected_total, warnings
        
    # Trường hợp 3: Tổng món hàng khớp hoàn toàn nhưng OCR tổng cộng bị lệch nhỏ do làm tròn/VAT
    if abs(sum_items - ocr_total) / sum_items <= tolerance_ratio:
        # Nếu có lệch nhỏ, tin tưởng tổng các mặt hàng
        corrected_total = sum_items
        warnings.append("AMOUNT_ADJUSTED_TO_ITEMS_SUM")
        return corrected_total, warnings
        
    # Trường hợp 4: Số tiền tổng bị đọc nhầm dấu phân tách thập phân thành hàng đơn vị (Lệch 1000 lần)
    # Ví dụ: Tổng món = 150.000, OCR đọc = 150
    if abs(sum_items - ocr_total * 1000) / sum_items <= tolerance_ratio:
        corrected_total = sum_items
        warnings.append("AMOUNT_CORRECTED_SCALE_1000X")
        return corrected_total, warnings
        
    return ocr_total, warnings
```

---

## VẤN ĐỀ 5: HIỆN TƯỢNG "BÈO DẠT MÂY TRÔI" (OCR PHÂN MẢNH CHỮ - TEXT FRAGMENTATION)

### 1. Phân tích kỹ thuật (Technical Deep Dive)
PaddleOCR thường phát hiện các từ trong cùng một cụm tên sản phẩm thành nhiều bounding box rời rạc theo chiều ngang thay vì gom thành một dòng liền mạch. 
* **Hậu quả:** Chuỗi tên sản phẩm `"Trà Sữa Matcha Trân Châu"` bị xé nhỏ thành các box độc lập: `["Trà Sữa"]`, `["Matcha"]`, `["Trân Châu"]`. Khi đưa các mảnh này qua SVM, mô hình phân loại sẽ thất bại (ví dụ: mảnh `["Trân Châu"]` bị phân nhầm thành `Others` thay vì `Food`). Đồng thời việc tính khoảng cách hình học để ghép giá tiền sẽ bị lệch cột hoàn toàn.

### 2. Biện pháp Tối ưu ngắn hạn (Quick Wins)
Xây dựng thuật toán **Hợp nhất hộp chữ theo chiều ngang (Horizontal Box Merging)** tại Backend trước khi xử lý NLU:
* **Bước 1: Gom nhóm theo dòng Y (Y-Axis Alignment Grouping):** Gom các box có độ đè bóng hình chiếu trục Y lớn (Y-Overlap $\ge 50\%$) vào chung một hàng.
* **Bước 2: Sắp xếp và đo khoảng cách X:** Trên mỗi hàng ngang, sắp xếp các box theo thứ tự tọa độ X tăng dần.
* **Bước 3: Hợp nhất theo khoảng cách giới hạn (Proximity Threshold):** Tính toán khoảng cách giữa cạnh phải của box trước và cạnh trái của box sau:
  $$\Delta X = X_{\text{left}}(\text{Box}_{k+1}) - X_{\text{right}}(\text{Box}_{k})$$
  Nếu $\Delta X \le 1.8 \times H_{\text{font\_height}}$ (với $H_{\text{font\_height}}$ là chiều cao trung bình của dòng chữ), tiến hành hợp nhất hai box này thành một: cộng chuỗi text (có khoảng trắng ngăn cách) và mở rộng bounding box bao phủ cả hai.

### 3. Biện pháp Tối ưu dài hạn (Scalable Solutions)
* **Tùy chỉnh tham số của mô hình phát hiện (PaddleOCR DB Detector tuning):**
  Điều chỉnh tăng tham số `det_db_box_thresh` và `det_db_unclip_ratio` trong file cấu hình của PaddleOCR. Việc tăng `unclip_ratio` giúp các vùng phân đoạn chữ gần nhau tự động phình to ra và kết dính lại với nhau thành một đa giác duy nhất trước khi đưa qua mô hình nhận dạng chữ VietOCR.
* **Mô hình gom nhóm dòng dựa trên Deep Learning (Text Line Clustering Network):**
  Áp dụng mô hình học sâu chuyên dụng như `LinkNet` hoặc `PixelLink` để dự đoán xác suất kết nối giữa các phân đoạn text, giúp tạo liên kết dòng bền vững ngay từ tầng xử lý hình ảnh.

### 4. Mã giả minh họa (Pseudo-code)
```python
from typing import List, Dict, Any

def merge_horizontal_fragmented_boxes(
    ocr_boxes: List[Dict[str, Any]], 
    font_height_scale: float = 1.8
) -> List[Dict[str, Any]]:
    """
    Hợp nhất các bounding box bị phân mảnh theo chiều ngang trên cùng một dòng Y.
    ocr_boxes: List các dict {"text": str, "bbox": [x1, y1, x2, y2]}
    """
    if not ocr_boxes:
        return []
        
    # Bước 1: Sắp xếp tất cả các box từ trên xuống dưới theo tọa độ y1
    ocr_boxes.sort(key=lambda b: b["bbox"][1])
    
    grouped_rows: List[List[Dict[str, Any]]] = []
    
    # Gom dòng thô bằng Y-Overlap
    for box in ocr_boxes:
        bbox = box["bbox"]
        h_box = bbox[3] - bbox[1]
        y_center = (bbox[1] + bbox[3]) / 2.0
        
        placed = False
        for row in grouped_rows:
            # Lấy box đầu tiên của row làm chuẩn dòng
            ref_box = row[0]["bbox"]
            ref_y_center = (ref_box[1] + ref_box[3]) / 2.0
            ref_h = ref_box[3] - ref_box[1]
            
            # Tính độ lệch tâm Y so với chiều cao box
            if abs(y_center - ref_y_center) < (min(h_box, ref_h) * 0.5):
                row.append(box)
                placed = True
                break
        if not placed:
            grouped_rows.append([box])
            
    merged_boxes = []
    
    # Bước 2: Hợp nhất ngang trên từng dòng
    for row in grouped_rows:
        # Sắp xếp các box trong dòng từ trái qua phải theo x1
        row.sort(key=lambda b: b["bbox"][0])
        
        current_merged = row[0]
        for next_box in row[1:]:
            curr_bbox = current_merged["bbox"]
            next_bbox = next_box["bbox"]
            
            curr_height = curr_bbox[3] - curr_bbox[1]
            x_distance = next_bbox[0] - curr_bbox[2]
            
            # Nếu khoảng cách ngang nhỏ hơn ngưỡng cho phép, tiến hành gộp
            if x_distance <= (curr_height * font_height_scale):
                # Hợp nhất text và cập nhật bbox [x1, y1, x2, y2]
                current_merged["text"] = current_merged["text"] + " " + next_box["text"]
                current_merged["bbox"] = [
                    min(curr_bbox[0], next_bbox[0]),
                    min(curr_bbox[1], next_bbox[1]),
                    max(curr_bbox[2], next_bbox[2]),
                    max(curr_bbox[3], next_bbox[3])
                ]
            else:
                merged_boxes.append(current_merged)
                current_merged = next_box
        merged_boxes.append(current_merged)
        
    return merged_boxes
```

---

## VẤN ĐỀ 6: LỖI "ẢNH NGHIÊNG XOẮN" (PERSPECTIVE SKEW) KHIẾN HÀM THUẦN HÌNH HỌC THẤT BẠI

### 1. Phân tích kỹ thuật (Technical Deep Dive)
Hóa đơn thường bị cong, uốn nếp hoặc người dùng chụp nghiêng góc (Keystone effect). Khi đó:
* **Tọa độ dòng Y bị trượt dốc:** Dòng chữ bị nghiêng một góc $\theta$. Tọa độ Y ở cột trái (Tên hàng) và cột phải (Giá tiền) bị lệch sâu (ví dụ: Tên món A ở Y=100 nhưng Giá món A ở Y=140).
* **Heuristic gom dòng ngang thất bại:** Thuật toán gom dòng theo Y tuyệt đối sẽ ghép nhầm Tên món B (Y=130) với Giá món A (Y=140) vì chúng vô tình có tọa độ Y gần nhau. Mối liên kết hàng ngang bị phá vỡ hoàn toàn.

### 2. Biện pháp Tối ưu ngắn hạn (Quick Wins)
* **Thuật toán hiệu chỉnh phối cảnh 2D phẳng (Homography Warp):**
  Trước khi chạy qua OCR, sử dụng thuật toán xử lý ảnh OpenCV để phát hiện biên hóa đơn (Canny Edge + Contour Detection), tìm ra 4 đỉnh của hóa đơn và thực hiện phép biến đổi phối cảnh (`cv2.warpPerspective`) để kéo phẳng hóa đơn về ảnh chữ nhật thẳng đứng chuẩn 2D.
* **Ghép cặp theo đường quét Baseline địa phương (Local Baseline Tracing):**
  Nếu ảnh bị cong hoặc mất góc không thể kéo phẳng, tính toán góc nghiêng trung bình cục bộ $\theta$ của các box chữ lân cận. Khi tìm giá tiền cho món hàng tại tâm $(X_1, Y_1)$, thay vì vẽ đường quét ngang $Y = Y_1$, ta vẽ đường quét chéo nghiêng:
  $$Y_{\text{search}} = Y_1 + (X_{\text{search}} - X_1) \times \tan(\theta)$$
  Chỉ tìm các box giá tiền nằm dọc theo đường quét chéo này.

### 3. Biện pháp Tối ưu dài hạn (Scalable Solutions)
* **Mô hình hiệu chỉnh độ cong hóa đơn (Deep Document Dewarping - DocTr / DewarpNet):**
  Triển khai mô hình học sâu (ví dụ `DewarpNet` hoặc `DocTr`) ở đầu pipeline. Mô hình này sử dụng mạng tích chập (CNN) dự đoán bản đồ tọa độ 3D lưới (3D Grid Mapping) của tờ giấy bị nhàu nát hoặc cong, sau đó khôi phục (unwarp) toàn bộ hình ảnh về trạng thái phẳng tuyệt đối trước khi OCR. Cách này giải quyết triệt để lỗi cong hóa đơn.

### 4. Mã giả minh họa (Pseudo-code)
```python
import math
import numpy as np
from typing import List, Dict, Any, Tuple

def get_bbox_center(bbox: List[int]) -> Tuple[float, float]:
    return (bbox[0] + bbox[2]) / 2.0, (bbox[1] + bbox[3]) / 2.0

def calculate_local_skew_angle(ocr_boxes: List[Dict[str, Any]]) -> float:
    """
    Tính góc nghiêng trung bình (radian) của các dòng chữ trên hóa đơn.
    Dựa trên độ nghiêng của các box đơn lẻ dài.
    """
    angles = []
    for box in ocr_boxes:
        bbox = box["bbox"]
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        
        # Chỉ xét các box dài đại diện cho cụm từ
        if w > h * 3:
            # Giả định góc nghiêng nhẹ, tính từ độ lệch Y-axis của bounding box nếu có xoay
            # Trong thực tế có thể dùng HoughLines trên ảnh thô.
            pass
    # Mặc định trả về 0.05 rad (~3 độ) làm ví dụ hoặc tính toán từ ảnh
    return 0.05 

def align_skewed_items_and_prices(
    ocr_boxes: List[Dict[str, Any]], 
    img_width: int,
    skew_angle_rad: float
) -> List[Tuple[str, int]]:
    """
    Ghép cặp tên món hàng và giá tiền dọc theo Baseline nghiêng của hóa đơn.
    """
    names = []
    prices = []
    boundary_x = img_width * 0.55  # Cột giá tiền thường nằm từ 55% chiều rộng trở đi
    
    # Phân loại ứng viên Tên và Giá
    for box in ocr_boxes:
        text = box["text"].strip()
        bbox = box["bbox"]
        
        # Kiểm tra xem có phải số tiền không
        numbers = [int(num.replace(".", "").replace(",", "")) for num in re.findall(r"\b\d{1,3}(?:[.,]\d{3})+\b|\b\d{4,9}\b", text)]
        
        if numbers and bbox[0] >= boundary_x:
            prices.append({"amount": numbers[-1], "bbox": bbox})
        else:
            names.append({"text": text, "bbox": bbox})
            
    matched_results: List[Tuple[str, int]] = []
    used_price_indices = set()
    
    # Duyệt qua các tên hàng từ trên xuống dưới
    names.sort(key=lambda x: x["bbox"][1])
    
    for name_box in names:
        name_x, name_y = get_bbox_center(name_box["bbox"])
        
        best_price_idx = -1
        min_distance = float("inf")
        
        # Quét tìm giá tiền nằm dọc theo đường Baseline nghiêng của tên hàng
        for idx, price_box in enumerate(prices):
            if idx in used_price_indices:
                continue
                
            price_x, price_y = get_bbox_center(price_box["bbox"])
            
            # Tính tọa độ Y kỳ vọng của giá tiền dựa trên góc nghiêng dòng chữ
            dx = price_x - name_x
            expected_price_y = name_y + dx * math.tan(skew_angle_rad)
            
            # Tính khoảng cách thực tế từ hộp giá tiền tới Baseline kỳ vọng
            vertical_deviation = abs(price_y - expected_price_y)
            
            # Nếu sai số dốc dọc nhỏ hơn 1.5 lần chiều cao font, coi như cùng dòng
            font_height = name_box["bbox"][3] - name_box["bbox"][1]
            if vertical_deviation < (font_height * 1.5):
                # Khoảng cách 2D Euclidean để tìm phần tử gần nhất
                dist = math.sqrt(dx**2 + (price_y - name_y)**2)
                if dist < min_distance:
                    min_distance = dist
                    best_price_idx = idx
                    
        if best_price_idx != -1:
            matched_results.append((name_box["text"], prices[best_price_idx]["amount"]))
            used_price_indices.add(best_price_idx)
        else:
            # Fallback nếu không có giá tiền tương ứng
            matched_results.append((name_box["text"], 0))
            
    return matched_results
```
