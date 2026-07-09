# CÔNG THỨC VÀ LÝ THUYẾT TÍNH CHI TIÊU LŨY KẾ SO VỚI HẠN MỨC (CUMULATIVE EXPENSE VS. BUDGET)

Tài liệu này định nghĩa chuẩn công thức toán học và logic tính toán được triển khai trong ứng dụng **Spending Stories (MiMo)** tại màn hình **Báo cáo Chi tiêu lũy kế so với hạn mức**.

---

## 1. Định nghĩa các biến số chính

Gọi kỳ báo cáo (ví dụ: tháng hiện tại hoặc khoảng thời gian T ngày) gồm các ngày từ d_1, d_2, ..., d_n.

- **N**: Tổng số ngày trong kỳ hạn mức (ví dụ: tháng có 30 hoặc 31 ngày).
- **B (Budget / Hạn mức)**: Tổng hạn mức chi tiêu được đặt cho kỳ (Ví dụ: 15,000,000 VNĐ).
- **E_i (Daily Expense)**: Tổng chi tiêu thực tế phát sinh trong ngày thứ i (1 <= i <= N).
- **C_k (Cumulative Expense - Chi tiêu lũy kế đến ngày k)**: Tổng số tiền đã chi tính từ ngày đầu kỳ d_1 đến hết ngày d_k:
  C_k = E_1 + E_2 + ... + E_k = C_(k-1) + E_k

---

## 2. Công thức Đường Hạn mức lý tưởng (Ideal Budget Line)

Đường hạn mức lý tưởng cho biết **mức chi tiêu chuẩn theo từng ngày** nếu phân bổ đều hạn mức B trong suốt N ngày của kỳ:

- **Hạn mức chi tiêu lý tưởng mỗi ngày (B_day)**:
  B_day = B / N

- **Hạn mức lũy kế lý tưởng đến ngày k (I_k)**:
  I_k = k * B_day = k * (B / N)

> **Ý nghĩa trên biểu đồ:**  
> Đường I_k là một **đường thẳng chéo chuẩn** nối từ (0, 0) đến (N, B). Nếu đường thực tế C_k nằm **dưới** đường lý tưởng I_k, bạn đang chi tiêu tiết kiệm hơn kế hoạch. Nếu nằm **trên** I_k, bạn đang có xu hướng vượt ngân sách.

---

## 3. Các chỉ số phân tích rủi ro & Cảnh báo (AI Risk Metrics)

### 3.1. Tỷ lệ tiêu hao hạn mức (Budget Consumption Rate)
Tại ngày hiện tại d_now (hoặc ngày cuối cùng có dữ liệu k):
Consumption Rate (%) = (C_now / B) * 100%

### 3.2. Tỷ lệ thời gian đã trôi qua (Time Elapsed Rate)
Time Rate (%) = (d_now / N) * 100%

### 3.3. Tốc độ đốt ngân sách (Burn Rate Index - β)
β = Consumption Rate / Time Rate = (C_now / B) / (d_now / N)

- **β < 0.95**: An toàn (Dưới hạn mức lý tưởng, kiểm soát tốt).
- **0.95 <= β <= 1.05**: Cân bằng (Bám sát kế hoạch).
- **β > 1.05**: Cảnh báo vượt hạn mức (Đang chi tiêu nhanh hơn tiến độ thời gian).

### 3.4. Dự báo tổng chi cuối kỳ (Projected End-of-Period Expense - P)
Dựa theo tốc độ chi tiêu trung bình mỗi ngày hiện tại:
P = (C_now / d_now) * N

- **Số tiền dự kiến vượt hạn mức (Projected Overspend)**:
  Δ_over = max(0, P - B)

---

## 4. Công thức tính Hạn mức còn lại an toàn mỗi ngày (Remaining Safe Daily Budget)

Số tiền tối đa bạn được phép chi tiêu trong mỗi ngày còn lại để không vượt hạn mức tổng B:

Safe Daily Budget = max(0, B - C_now) / (N - d_now)

---

## 5. Ví dụ minh họa thực tế

Giả sử **Tháng 7 có N = 31 ngày**, Hạn mức **B = 15,000,000 VNĐ**:
- Hôm nay là **ngày 15 (d_now = 15)**:
  - Hạn mức lý tưởng đến ngày 15: I_15 = 15 * (15,000,000 / 31) ≈ 7,258,000 VNĐ.
- Nếu chi tiêu lũy kế thực tế đến ngày 15 là **C_15 = 9,000,000 VNĐ**:
  - Tỷ lệ tiêu hao: 9,000,000 / 15,000,000 = 60% (trong khi thời gian mới trôi qua 48.38%).
  - Chỉ số Burn Rate β = 60% / 48.38% = 1.24 > 1.05 => **Cảnh báo vượt hạn mức**.
  - Dự báo cuối kỳ: P = (9,000,000 / 15) * 31 = 18,600,000 VNĐ (Dự kiến vượt 3,600,000 VNĐ).
  - Hạn mức an toàn cho 16 ngày còn lại: (15,000,000 - 9,000,000) / 16 = 375,000 VNĐ/ngày.
