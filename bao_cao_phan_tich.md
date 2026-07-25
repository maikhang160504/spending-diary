# BÁO CÁO PHÂN TÍCH LUẬN VĂN - HỘI ĐỒNG PHẢN BIỆN
## Đề tài: Ứng dụng Quản lý Chi tiêu Cá nhân Thông minh (Spending Diary)

---

# PHẦN 1: BÁO CÁO ĐÁNH GIÁ CHI TIẾT

---

## BƯỚC 1: ĐÁNH GIÁ TỔNG QUAN

| Chương | Số trang (ước tính) | Mức độ quan trọng | Có thể giảm (%) | Nhận xét |
|--------|---------------------|-------------------|-----------------|----------|
| Abstract + Mục lục | ~2 | Rất cao | 10% | Tốt, súc tích. Abstract đủ học thuật |
| Phần Giới thiệu | ~8 | Rất cao | 25% | Có nội dung lặp lại giữa mục 1, 2, 3 và 6. Mục 7 (Bố cục) không cần thiết |
| Chương 1 - Đặc tả yêu cầu | ~12 | Cao | 30% | Đặc tả Use Case quá dài, chi tiết use case thứ yếu có thể rút gọn mạnh |
| Chương 2 - Cơ sở toán học & Thiết kế | ~15 | Rất cao | 20% | Các mục về bảo mật, thông báo, quản lý ví có thể gộp lại |
| Chương 3 - Kiến trúc & Thiết kế hệ thống | ~18 | Rất cao | 15% | Chứa nhiều sơ đồ và luồng sự kiện quan trọng |
| Chương 4 - Cài đặt & Triển khai | ~10 | Cao | 35% | Phần mô tả giao diện dài, nhiều chỗ thay bằng tham chiếu phụ lục |
| Chương 5 - Thực nghiệm & Đánh giá | ~15 | Rất cao | 15% | Đây là chương cốt lõi nhất, cần giữ |
| Kết luận | ~3 | Cao | 20% | Kết luận tốt nhưng phần hướng phát triển hơi dài |
| Tài liệu tham khảo | ~2 | Rất cao | 0% | Giữ nguyên |
| Phụ lục | ~10 | Thấp | 50% | Liệt kê quá dài, có thể đề cập không cần đặc tả chi tiết |

**Chẩn đoán tổng thể:**
- **Quá dài:** Chương 1 (Use Case chi tiết), Chương 4 (UI/UX mô tả), Phụ lục
- **Thiếu trọng tâm:** Phần Giới thiệu (lặp mục tiêu nhiều lần), Mục 3.12 (Thông báo), Mục 3.13 (WebAdmin)
- **Lặp lại chương khác:** Phần Giới thiệu lặp nội dung của Chương 1 và Chương 3
- **Dấu hiệu giáo trình hóa:** Mục 5.4 (mô tả PaddleOCR như tài liệu kỹ thuật), Mục 1.5.1 (RUP Use Case cứng nhắc)

---

## BƯỚC 2: PHÂN TÍCH TỪNG MỤC

| Mục | Vai trò trong nghiên cứu | Mức độ cần thiết | Hành động đề xuất | Lý do |
|-----|--------------------------|------------------|-------------------|-------|
| Abstract | Tóm tắt toàn bộ đề tài | Rất cao | GIỮ NGUYÊN | Bắt buộc trong học thuật |
| Giới thiệu §1 - Đặt vấn đề | Nêu bối cảnh và vấn đề | Cao | RÚT GỌN 40% | Đoạn đầu hay, nhưng diễn giải về MoneyLover quá dài |
| Giới thiệu §2 - Nghiên cứu liên quan | So sánh với các giải pháp hiện có | Cao | RÚT GỌN 30% | Có thể rút bullet points thành đoạn văn ngắn hơn |
| Giới thiệu §3 - Mục tiêu | Định hướng nghiên cứu | Rất cao | RÚT GỌN 20% | Mục a-f có thể gộp thành 3-4 nhóm |
| Giới thiệu §4 - Đối tượng & Phạm vi | Giới hạn đề tài | Cao | RÚT GỌN 20% | Tốt, chỉ cần rút nhẹ |
| Giới thiệu §5 - Phương pháp | Phương pháp khoa học | Rất cao | GIỮ NGUYÊN | Đây là phần quan trọng với hội đồng |
| Giới thiệu §6 - Nội dung | Liệt kê nội dung | Trung bình | GỘP VỚI MỤC KHÁC | Lặp lại §3 và cấu trúc chương. Gộp vào §7 Bố cục |
| Giới thiệu §7 - Bố cục | Mô tả cấu trúc luận văn | Thấp | XÓA HOÀN TOÀN | Không cần khi đã có Mục lục chi tiết |
| Chương 1 §1.1 - Khảo sát hiện trạng | Bối cảnh thực tiễn | Cao | RÚT GỌN 35% | Lặp ý với Phần Giới thiệu §1 |
| Chương 1 §1.2 - Kiến trúc giải pháp | Tổng quan kỹ thuật | Cao | RÚT GỌN 20% | Lặp nhẹ với Chương 2 & 3 |
| Chương 1 §1.3 - Yêu cầu chức năng | Đặc tả phần mềm | Cao | RÚT GỌN 20% | Tốt, cần giữ để bảo vệ |
| Chương 1 §1.4 - Use Case tổng quát | Sơ đồ hệ thống | Cao | GIỮ NGUYÊN | Sơ đồ PlantUML có giá trị |
| Chương 1 §1.5.1 - UC chi tiết (5 UC) | Đặc tả kịch bản AI | Cao | RÚT GỌN 30% | Mỗi UC có thể bớt 30-40% chữ ở "Luồng sự kiện" |
| Chương 1 §1.5.2 - UC tóm lược (9 UC) | Đặc tả hệ thống phụ | Thấp | CHUYỂN PHỤ LỤC | 9 UC thứ yếu không cần trong thân chương |
| Chương 1 §1.6 - Yêu cầu phi chức năng | Chất lượng phần mềm | Cao | RÚT GỌN 20% | Bảng NFR dài, có thể tóm gọn hơn |
| Chương 2 §2.1 - Cơ sở toán học AI | Lý thuyết cốt lõi | Rất cao | GIỮ NGUYÊN | Đây là đóng góp học thuật quan trọng |
| Chương 2 §2.2 - Agentic RAG | Kiến trúc AI chống ảo giác | Rất cao | GIỮ NGUYÊN | Đổi mới sáng tạo cốt lõi |
| Chương 3 §3.1 - Kiến trúc Microservices | Thiết kế hệ thống | Rất cao | GIỮ NGUYÊN | Cơ sở của toàn bộ hệ thống |
| Chương 3 §3.2 - Sequence Diagrams | Luồng xử lý | Cao | RÚT GỌN 15% | Giảm mô tả text bên dưới sơ đồ |
| Chương 3 §3.3 - Class Diagram | Cấu trúc code | Cao | GIỮ NGUYÊN | Có giá trị học thuật |
| Chương 3 §3.4 - Hybrid Personalization | Đổi mới kỹ thuật | Rất cao | GIỮ NGUYÊN | Đây là điểm đột phá kỹ thuật quan trọng |
| Chương 3 §3.5 - Thuật toán báo cáo | Toán học ứng dụng | Cao | GIỮ NGUYÊN | Công thức toán là đóng góp khoa học |
| Chương 3 §3.6 - ERD | Thiết kế CSDL | Cao | GIỮ NGUYÊN | Bắt buộc |
| Chương 3 §3.7 - Quản lý ví chung | Tính năng phụ | Trung bình | RÚT GỌN 50% | Không liên quan trực tiếp AI pipeline |
| Chương 3 §3.8 - Hạn mức & Mục tiêu | Tính năng phụ | Trung bình | RÚT GỌN 40% | Cần đề cập nhưng không cần chi tiết |
| Chương 3 §3.9 - Thanh toán Premium | Tính năng hệ thống | Thấp | RÚT GỌN 50% | Không liên quan AI, đưa vào 1 đoạn ngắn |
| Chương 3 §3.10 - REST API | Đặc tả kỹ thuật | Cao | RÚT GỌN 30% | Bảng API đủ, bỏ phần mô tả dài |
| Chương 3 §3.11 - Bảo mật | Yêu cầu phi chức năng | Trung bình | RÚT GỌN 40% | Quan trọng nhưng đang quá chi tiết |
| Chương 3 §3.12 - Thông báo | Tính năng hệ thống | Thấp | GỘP VỚI MỤC KHÁC | Gộp vào mục triển khai hoặc xóa |
| Chương 3 §3.13 - WebAdmin | Tính năng quản trị | Trung bình | RÚT GỌN 50% | Đã đề cập ở Chương 4 |
| Chương 4 §4.1 - UI/UX | Triển khai | Trung bình | RÚT GỌN 50% | Placeholder ảnh chiếm không gian, mô tả màu sắc dư thừa |
| Chương 4 §4.2 - NLU Dataset | Phương pháp dữ liệu | Rất cao | RÚT GỌN 20% | Quan trọng, nhưng phần mô phỏng 1500 users dài |
| Chương 4 §4.3 - WebAdmin Dashboard | Triển khai | Cao | RÚT GỌN 30% | Quan trọng (Active Learning), rút phần giải thích hiển nhiên |
| Chương 4 §4.4 - Responsive | Triển khai | Thấp | CHUYỂN PHỤ LỤC | Không liên quan AI pipeline, kỹ thuật phổ biến |
| Chương 4 §4.5 - DevOps | Triển khai hệ thống | Trung bình | RÚT GỌN 40% | Cần đề cập nhưng không cần chi tiết infrastructure |
| Chương 5 §5.1 - Mô tả Dataset | Thực nghiệm | Rất cao | RÚT GỌN 15% | Quan trọng, chỉ rút phần mô tả nhân khẩu học |
| Chương 5 §5.2 - Cấu hình phần cứng | Thực nghiệm | Cao | GIỮ NGUYÊN | Bắt buộc để tái lập kết quả |
| Chương 5 §5.3 - Benchmark NLU | Kết quả cốt lõi | Rất cao | GIỮ NGUYÊN | Đây là trái tim của luận văn |
| Chương 5 §5.4 - OCR Evaluation | Kết quả thực nghiệm | Cao | RÚT GỌN 25% | Phần mô tả PaddleOCR như tài liệu kỹ thuật |
| Chương 5 §5.5 - KIE Evaluation | Kết quả thực nghiệm | Rất cao | GIỮ NGUYÊN | Bảng F1 so sánh baseline rất quan trọng |
| Chương 5 §5.6 - Stability Test | Kết quả thực nghiệm | Cao | RÚT GỌN 20% | Kết quả tốt, rút phần mô tả kịch bản kiểm thử |
| Kết luận §1 | Tổng kết | Rất cao | GIỮ NGUYÊN | Đủ súc tích |
| Kết luận §1.1 - Hạn chế | Tự phê bình khoa học | Rất cao | GIỮ NGUYÊN | Bắt buộc với hội đồng |
| Kết luận §2 - Hướng phát triển | Tầm nhìn | Cao | RÚT GỌN 25% | Đang hơi chi tiết với một vài hướng |
| Phụ lục - UI Screens | Minh họa | Thấp | RÚT GỌN 60% | Placeholder ảnh + mô tả lặp lại không giá trị |

---

## BƯỚC 3: PHÂN TÍCH NỘI DUNG DÀI DÒNG

| Vị trí | Nội dung đang gặp vấn đề | Loại vấn đề | Cách xử lý |
|--------|--------------------------|-------------|------------|
| Giới thiệu §1 (dòng 62-65) | "Trong nhịp sống hiện đại... thời gian ngắn sử dụng" - đoạn văn quá dài về data entry fatigue | Diễn giải dài dòng | Rút xuống 2 câu |
| Giới thiệu §6 (dòng 151-156) | Liệt kê 5 nội dung nghiên cứu hoàn toàn lặp lại mục tiêu §3 | Trùng ý | XÓA - đã có ở §3 |
| Giới thiệu §7 (dòng 159-174) | Mô tả bố cục chương theo dạng kể lại mục lục | Không có giá trị khoa học | XÓA hoàn toàn |
| Chương 1 §1.1 (dòng 183-190) | "Qua khảo sát... cách tự nhiên" - lặp lại ý đặt vấn đề | Trùng ý với Giới thiệu §1 | Rút xuống 3-4 câu |
| Chương 1 §1.2 (dòng 193-201) | Mô tả 4 tầng kiến trúc chi tiết lặp với Chương 3 | Trùng ý với chương sau | Tóm tắt trong 1 đoạn, thêm "xem Chương 3" |
| Chương 1 §1.5.1 UC1 (dòng 291-307) | Luồng sự kiện chính 7 bước viết quá chi tiết như user story | Diễn giải hiển nhiên | Rút mỗi bước xuống 1 dòng gạch đầu dòng |
| Chương 1 §1.5.1 UC2-5 | Tương tự UC1, mỗi UC có 7-8 bước chi tiết | Diễn giải hiển nhiên | Rút mỗi UC xuống 50% |
| Chương 3 §3.2 (dòng 730-808) | Sau mỗi sơ đồ sequence có đoạn mô tả lại từng bước | Trùng ý với sơ đồ | Xóa các đoạn mô tả lại - sơ đồ đã tự giải thích |
| Chương 3 §3.7 (dòng 1071-1074) | Mô tả RBAC, Invite Code, Multi-tenant - kiến thức kỹ thuật phổ biến | Kiến thức nền phổ biến | Rút xuống 3 bullet points ngắn |
| Chương 3 §3.12 (dòng 1119-1125) | Mô tả 3 loại thông báo đều hiển nhiên | Giải thích kiến thức phổ thông | Gộp vào 1 câu trong §4.5 DevOps |
| Chương 4 §4.1 (dòng 1141-1158) | Mô tả màu sắc, font chữ, thiết kế không đóng góp khoa học | Không phục vụ nghiên cứu AI | Rút xuống 1 đoạn, tham chiếu phụ lục |
| Chương 4 §4.2 (dòng 1164-1175) | Chi tiết phân bổ nhân khẩu học, Numbeo, GSMK - dài 12 dòng | Liệt kê quá nhiều | Rút xuống 3-4 câu + 1 trích dẫn |
| Chương 4 §4.4 (dòng 1192-1197) | Kỹ thuật Responsive (max-width, safe area) - kiến thức phổ biến | Kiến thức nền phổ biến | Chuyển phụ lục hoặc xóa |
| Chương 5 §5.4 (dòng 1330-1338) | Mô tả PaddleOCR/DBNet như đọc tài liệu kỹ thuật | Giáo trình hóa | Rút xuống 3-4 câu mô tả lý do chọn |
| Phụ lục (dòng 1418-1539) | Liệt kê 20+ màn hình với placeholder `[CHÈN ẢNH]` | Placeholder không có giá trị | Rút xuống danh mục tóm tắt, xóa placeholder |

---

## BƯỚC 4: PHÂN TÍCH HÌNH ẢNH VÀ BẢNG BIỂU

| Hình/Bảng | Có cần thiết không | Đề xuất |
|-----------|-------------------|---------|
| Hình 1.1: Use Case Diagram (PlantUML) | Có | Giữ nguyên |
| Hình 2.1-2.5: Sequence Diagrams NLU/OCR | Có | Giữ nguyên |
| Hình 3.1: Kiến trúc Microservices | Có - quan trọng nhất | Giữ nguyên |
| Hình 3.2-3.5: Sequence Diagrams backend | Có | Thu nhỏ mô tả, giữ sơ đồ |
| Hình 3.6: Class Diagram | Có | Giữ nguyên |
| Hình 3.7: Sequence Hybrid Personalization | Có - đổi mới kỹ thuật | Giữ nguyên |
| Hình 3.8: ERD (10 thực thể) | Có | Giữ nguyên |
| Hình 4.1-4.5: Screenshots app (placeholder) | KHÔNG - chỉ là placeholder text | Xóa placeholder, giữ chú thích tham chiếu |
| Bảng 3.1-3.2: REST API | Có | Thu nhỏ - giữ header, xóa mô tả verbose |
| Hình 5.1: Biểu đồ xychart NLU Benchmark | Có | Giữ nguyên |
| Bảng 5.3 (NLU Benchmark 3 kiến trúc) | Có - trái tim của thực nghiệm | Giữ nguyên |
| Bảng 5.3 (KIE F1-Score) - ĐÃ ĐÁNH SỐ TRÙNG | Có - nhưng đánh số trùng | Giữ nguyên, SỬA số thành Bảng 5.4 |
| Hình 5.2: LayoutLMv3 visualization | Có - kết quả thực nghiệm quan trọng | Giữ nguyên |
| Phụ lục: 20+ Screenshots placeholder | KHÔNG | Xóa placeholder, tóm tắt bằng danh mục |

---

## BƯỚC 5: PHÂN TÍCH CHƯƠNG THỰC NGHIỆM (Chương 5)

**Đánh giá:**
- ✅ Tập dữ liệu: Mô tả kỹ lưỡng, có trích dẫn - **GIỮ nhưng rút phần nhân khẩu học**
- ✅ Cấu hình phần cứng: Chuẩn học thuật - **GIỮ NGUYÊN**
- ✅ Bảng Benchmark NLU 3 kiến trúc: Rất tốt, đây là đóng góp cốt lõi - **GIỮ NGUYÊN**
- ⚠️ Mục 5.4 OCR: Dài 8 đoạn mô tả về PaddleOCR/DBNet như tài liệu kỹ thuật → **RÚT XUỐNG 50%**
- ✅ Bảng KIE F1-Score: Quan trọng, có baseline comparison - **GIỮ NGUYÊN**
- ⚠️ Mục 5.6 Load Testing: Mô tả kịch bản 500 VU khá chi tiết → **RÚT 20%**

**Nội dung nên chuyển phụ lục:**
- Siêu tham số tinh chỉnh chi tiết từng model (dòng 1236-1241) → Có thể để phụ lục kỹ thuật

**Nội dung nên loại bỏ:**
- Đoạn mô tả cấu trúc PaddleOCR như giới thiệu thư viện (dòng 1330-1332)
- Đoạn giải thích "Kết quả đầu ra từ phân hệ này... đóng vai trò đầu vào" (dòng 1338) - hiển nhiên

---

## BƯỚC 6: ĐÁNH GIÁ KHẢ NĂNG RÚT GỌN

| Thành phần | Trang hiện tại (ước tính) | Trang sau tối ưu |
|------------|--------------------------|------------------|
| Abstract + Mục lục | 2 | 2 |
| Phần Giới thiệu | 8 | 5 |
| Chương 1 | 14 | 9 |
| Chương 2 (Cơ sở lý thuyết + Thiết kế hệ thống) | 20 | 16 |
| Chương 3 (Kiến trúc chi tiết) | 18 | 15 |
| Chương 4 (Cài đặt & Triển khai) | 12 | 7 |
| Chương 5 (Thực nghiệm) | 16 | 13 |
| Kết luận | 3 | 3 |
| Tài liệu tham khảo | 2 | 2 |
| Phụ lục | 10 | 4 |
| **TỔNG** | **~105** | **~76** |

**Ước lượng:**
- Giảm tối thiểu: **~15% (~16 trang)** - chỉ xóa nội dung lặp rõ ràng
- Giảm hợp lý: **~28% (~30 trang)** - áp dụng toàn bộ đề xuất
- Giảm tối đa vẫn an toàn: **~35% (~37 trang)** - chuyển phụ lục tối đa

---

## BƯỚC 7: KẾ HOẠCH RÚT GỌN

### Bắt buộc rút (ảnh hưởng độ sạch mà không mất giá trị khoa học)
- Xóa Giới thiệu §6 (Nội dung nghiên cứu) - lặp hoàn toàn với §3
- Xóa Giới thiệu §7 (Bố cục luận văn) - đã có mục lục
- Rút Chương 1 §1.1 xuống 3-4 câu (lặp với Giới thiệu §1)
- Rút Chương 1 §1.2 xuống 1 đoạn tổng quan (chi tiết đã ở Chương 3)
- Chuyển Chương 1 §1.5.2 (9 UC thứ yếu) vào phụ lục
- Xóa mô tả lại bên dưới các sơ đồ sequence diagram (đã có sơ đồ)
- Rút §3.12 (Thông báo) và §3.13 (WebAdmin) thành 1 đoạn kết hợp
- Xóa placeholder ảnh trong Chương 4 và Phụ lục (chỉ giữ caption)

### Nên rút (cải thiện chất lượng học thuật)
- Rút mỗi Use Case trong §1.5.1 xuống 50% (bỏ bước hiển nhiên)
- Rút §3.7, §3.8, §3.9 mỗi mục còn 4-5 câu
- Rút mô tả chi tiết PaddleOCR trong §5.4 xuống 3-4 câu
- Rút §4.1 (UI/UX) xuống 1 đoạn + tham chiếu phụ lục
- Rút §4.4 (Responsive) hoặc chuyển phụ lục
- Rút phần nhân khẩu học/Numbeo trong §4.2 xuống 2-3 câu
- Sửa lỗi đánh số trùng Bảng 5.3 thành Bảng 5.4 (KIE)

### Có thể giữ nguyên
- Abstract - súc tích và đủ
- Giới thiệu §2, §3, §4, §5 - cần thiết
- Chương 1 §1.3, §1.4, §1.5.1 (sau khi rút gọn), §1.6 - cần cho bảo vệ
- Toàn bộ Chương 2 (Cơ sở toán học AI) - đây là đóng góp lý thuyết
- Toàn bộ Chương 3 §3.1-§3.6 - kiến trúc hệ thống cốt lõi
- Toàn bộ Chương 5 §5.1-§5.3, §5.5 - kết quả thực nghiệm
- Toàn bộ Kết luận và Tài liệu tham khảo

---

# PHẦN 2: DANH SÁCH NỘI DUNG ĐỀ NGHỊ XÓA/RÚT/GỘP

## Đề nghị XÓA HOÀN TOÀN:
1. **Giới thiệu §6 "Nội dung nghiên cứu"** (dòng 149-156) → Lặp hoàn toàn với §3
2. **Giới thiệu §7 "Bố cục luận văn"** (dòng 158-174) → Thay thế bằng Mục lục
3. **Tất cả placeholder ảnh** `[CHÈN ẢNH...]` trong Chương 4 và Phụ lục → Giữ caption, xóa placeholder
4. **Đoạn mô tả lại sơ đồ sequence** sau mỗi sơ đồ trong Chương 3 → Sơ đồ tự giải thích
5. **Chương 3 §3.12 "Thông báo"** → Gộp 1 câu vào §4.5

## Đề nghị RÚT GỌN mạnh (>40%):
6. **Giới thiệu §1** → Giữ 2-3 đoạn cốt lõi về data entry fatigue và AI opportunity
7. **Chương 1 §1.1** → Giữ 3-4 câu về bối cảnh + 3 chế độ hiển thị
8. **Chương 1 §1.2** → Tóm tắt 1 đoạn 4-5 câu, "xem chi tiết Chương 3"
9. **Chương 1 §1.5.1** → Rút mỗi UC xuống: Mô tả (2 dòng) + Luồng chính (5 bullet) + Ngoại lệ (1-2 dòng)
10. **Chương 3 §3.7-§3.9** → Mỗi mục còn 3-5 câu bullet points
11. **Chương 3 §3.11** → Giữ 4 bullet points, bỏ mô tả chi tiết mỗi điểm
12. **Chương 4 §4.1** → 1 đoạn mô tả triết lý UI + 3 màn hình tiêu biểu, tham chiếu Phụ lục
13. **Chương 4 §4.2** → Giữ thống kê dataset, bỏ phần mô phỏng nhân khẩu học chi tiết
14. **Chương 4 §4.4** → Chuyển phụ lục kỹ thuật
15. **Chương 5 §5.4** → Còn 4-5 câu lý do chọn PaddleOCR + VietOCR + kết quả validation set
16. **Phụ lục** → Chỉ giữ danh sách màn hình, bỏ mô tả từng màn hình

## Đề nghị CHUYỂN PHỤ LỤC:
17. **Chương 1 §1.5.2** (9 UC thứ yếu) → Phụ lục B
18. **Siêu tham số chi tiết** (§5.1 - Fine-tuning config) → Phụ lục kỹ thuật
19. **Chương 4 §4.4** (Responsive Engineering) → Phụ lục kỹ thuật

---

# PHẦN 3: ƯỚC LƯỢNG SỐ TRANG TIẾT KIỆM

| Thao tác | Trang tiết kiệm |
|----------|----------------|
| Xóa §6 và §7 Giới thiệu | ~1.5 trang |
| Xóa placeholder ảnh (20+ chỗ) | ~2 trang |
| Xóa mô tả lại sau sơ đồ | ~2 trang |
| Rút gọn Use Case chi tiết §1.5.1 | ~2 trang |
| Chuyển §1.5.2 sang phụ lục | ~3 trang |
| Rút gọn §3.7-§3.9-§3.11-§3.12 | ~2 trang |
| Rút gọn §4.1, §4.2, §4.4 | ~3 trang |
| Rút gọn §5.4 OCR | ~1 trang |
| Rút gọn Phụ lục | ~4 trang |
| Rút gọn các đoạn lan man khác | ~2.5 trang |
| **TỔNG ƯỚC TÍNH** | **~23 trang (~22%)** |

---

*Báo cáo được lập bởi Hội đồng Phản biện Nội bộ - Phiên họp 2026-07-25*
