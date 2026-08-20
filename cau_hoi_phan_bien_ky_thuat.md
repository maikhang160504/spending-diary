Dựa trên quá trình phân tích tài liệu báo cáo luận văn, tài liệu ghi chú sửa lỗi, kiến trúc phần mềm và các buổi thảo luận chuyên sâu, hội đồng phản biện đưa ra 15 câu hỏi chất vấn trọng tâm nhằm đánh giá năng lực giải quyết các bài toán kỹ thuật cốt lõi trong hệ thống quản lý chi tiêu.

### Nhóm 1: Xử lý ngôn ngữ tự nhiên và mô hình học máy

Câu 1: Cơ chế khai thác ngữ cảnh hai chiều của mô hình PhoBERT trong phân loại câu lệnh tiếng Việt
- Vị trí logic: Mục mô hình xử lý ngữ nghĩa tiếng Việt PhoBERT và bảng đánh giá so sánh các mô hình NLU tại chương 3.
- Điểm yếu tiềm ẩn: Tiếng Việt có đặc thù là ngôn ngữ đơn lập với nhiều từ ghép và hiện tượng từ đa nghĩa. Khi người dùng nhập liệu chi tiêu tự do, họ thường sử dụng cấu trúc câu rút gọn, từ lóng hoặc viết tắt, ví dụ như ăn phở 50 cành. Nếu hệ thống chỉ áp dụng phương pháp đếm từ khóa truyền thống như TF-IDF, mô hình sẽ không thể hiểu được mối quan hệ giữa các từ và dẫn đến phân loại sai lệch ý định hoặc danh mục.
- Gợi ý trả lời: Để hiểu và nhận dạng ngôn ngữ tự nhiên tiếng Việt, PhoBERT thực hiện ba bước cốt lõi:
  1. Nối đúng từ ghép tiếng Việt: Tự động gom các tiếng đi liền có nghĩa thành một từ ghép bằng dấu gạch dưới, ví dụ ăn phở thành ăn_phở, cà phê thành cà_phê, giúp mô hình không bị hiểu sai nghĩa của từng từ đơn lẻ.
  2. Đọc toàn bộ câu cùng lúc để hiểu ngữ cảnh: Sử dụng cơ chế tự chú ý hai chiều để nhìn toàn bộ câu ở cả trước và sau cùng một lúc, tính toán sự liên kết giữa các từ. Nhờ đó, từ lóng như 50 cành được hiểu chính xác là 50 nghìn đồng vì đứng cạnh số 50 và món ăn phở.
  3. Đúc kết ý nghĩa và phân loại: Gom toàn bộ ngữ cảnh câu thành một dãy số đặc trưng véc-tơ và đưa qua bộ phân loại để xác định chính xác ý định thêm chi tiêu và phân vào danh mục ăn uống.

Câu 2: Động lực lựa chọn và đối sánh ba mô hình TF-IDF, PhoBERT và Qwen 2.5
- Vị trí logic: Bảng đánh giá và so sánh hiệu năng các mô hình NLU tại chương 3 và kiến trúc suy luận phân tầng.
- Điểm yếu tiềm ẩn: Việc tích hợp đồng thời ba mô hình học máy khác nhau cho cùng một bài toán phân loại có thể bị đánh giá là dư thừa hoặc làm phức tạp hóa kiến trúc hệ thống nếu không làm rõ được lý do kỹ thuật và mục tiêu khoa học.
- Gợi ý trả lời: Đề tài lựa chọn và so sánh ba mô hình này dựa trên hai mục tiêu cốt lõi:
  1. Về mặt khoa học: Đánh giá thực nghiệm ba thế hệ công nghệ xử lý ngôn ngữ trên cùng một tập dữ liệu, từ phương pháp thống kê từ khóa TF-IDF, học sâu hiểu ngữ cảnh PhoBERT, đến mô hình ngôn ngữ lớn Qwen 2.5, qua đó chứng minh rõ ràng sự đánh đổi giữa độ chính xác và tài nguyên phần cứng.
  2. Về mặt thực tế: Xây dựng kiến trúc phân tầng tối ưu cho hệ thống. TF-IDF và PhoBERT có tốc độ phản hồi cực nhanh từ một đến vài chục mili-giây giúp tiết kiệm tài nguyên máy chủ cho các câu thông thường, trong khi Qwen 2.5 đạt độ chính xác cao nhất để giải quyết các câu khó và tác vụ hội thoại. Đồng thời, hệ thống cho phép quản trị viên linh hoạt chuyển đổi bộ máy suy luận trên Web Admin tùy theo tải máy chủ tại từng thời điểm.

Câu 3: Bản chất cơ chế nhận dạng của ba thế hệ công nghệ
- Vị trí logic: Mục tổng quan các kỹ thuật xử lý ngôn ngữ tự nhiên tại chương 2 và chương 3.
- Điểm yếu tiềm ẩn: Cần làm rõ sự khác biệt cốt lõi về mặt toán học và cơ chế trích xuất đặc trưng giữa ba phương pháp để không bị nhầm lẫn giữa véc-tơ đếm từ và véc-tơ ngữ nghĩa.
- Gợi ý trả lời:
  1. TF-IDF: Nhận dạng bằng tần suất từ khóa rời rạc. Mô hình đếm sự xuất hiện của các từ trên mặt chữ và chuyển thành véc-tơ tần suất để phân loại, không có khả năng hiểu ý nghĩa câu.
  2. PhoBERT: Nhận dạng bằng ngữ nghĩa theo ngữ cảnh hai chiều. Mô hình sử dụng cơ chế tự chú ý của kiến trúc Transformer Encoder để liên kết các từ ghép tiếng Việt đứng trước và sau, hiểu được nghĩa của câu dù có chứa từ lóng.
  3. Qwen 2.5: Nhận dạng bằng suy luận logic đa tầng. Mô hình ngôn ngữ lớn dựa trên hàng tỷ tham số để suy luận theo ngữ cảnh sâu, xử lý tốt các câu phức tạp đa ý định, câu tỉnh lược và xuất dữ liệu JSON có cấu trúc nghiêm ngặt.

Câu 4: Lý do ưu tiên độ chính xác hơn tốc độ phản hồi và định hướng phát triển
- Vị trí logic: Đoạn phân tích sự đánh đổi giữa độ trễ và độ chính xác tại bảng đánh giá NLU chương 3.
- Điểm yếu tiềm ẩn: Qwen 2.5 có độ trễ suy luận khoảng vài giây, có thể bị đánh giá là làm giảm trải nghiệm người dùng so với các mô hình phản hồi tức thì.
- Gợi ý trả lời:
  1. Lý do ưu tiên độ chính xác: Trong bài toán tài chính, sự chính xác của số tiền và danh mục là yếu tố sống còn. Tầng 1 đóng vai trò định tuyến, nếu Tầng 1 nhận diện sai ý định thì Tầng 2 sẽ nạp sai bộ quy tắc và dẫn đến việc lưu sai cơ sở dữ liệu mà không thể cứu vãn.
  2. Định hướng tương lai: Áp dụng kỹ thuật lượng tử hóa để nén mô hình ngôn ngữ lớn nhằm giảm độ trễ, hoặc tiếp tục thu thập dữ liệu phản hồi thực tế của người dùng để huấn luyện PhoBERT và TF-IDF đạt độ chính xác cao tương đương để thay thế dần cho mô hình ngôn ngữ lớn.

Câu 5: Lý do chia luồng xử lý AI thành 2 tầng độc lập thay vì 1 tầng đơn khối
- Vị trí logic: Sơ đồ luồng phân tầng xử lý ngôn ngữ tự nhiên tại chương 3.
- Điểm yếu tiềm ẩn: Thiết kế 2 tầng có thể bị xem là làm tăng số bước xử lý so với việc dùng một câu lệnh prompt duy nhất cho mô hình ngôn ngữ lớn làm toàn bộ tác vụ.
- Gợi ý trả lời:
  1. Tránh quá tải chỉ thị cho mô hình: Nếu dùng 1 câu lệnh prompt duy nhất để giải quyết mọi việc (vừa phân loại, vừa bóc tách, vừa đóng vai trợ lý), mô hình rất dễ bị quá tải, dẫn đến sinh ảo giác và làm vỡ định dạng cấu trúc dữ liệu JSON.
  2. Đảm bảo độ chính xác theo ý định: Chia làm 2 tầng giúp Tầng 1 chốt sẵn hướng đi, Tầng 2 chỉ cần nạp đúng một bộ quy tắc chuyên biệt cho ý định đó, giúp phản hồi chuẩn xác.
  3. Cho phép nâng cấp độc lập: Quản trị viên có thể huấn luyện lại và thay thế mô hình mới cho từng tầng riêng biệt trực tiếp trên Web Admin theo cơ chế nạp nóng mà không cần khởi động lại máy chủ.

Câu 6: Xử lý câu lệnh hỗn hợp chứa cả giao dịch chi tiêu và câu lệnh điều khiển
- Vị trí logic: Luồng điều phối AI Chat tại máy chủ Backend.
- Điểm yếu tiềm ẩn: Khi người dùng nhập một câu chứa cả việc lưu tiền và yêu cầu báo cáo (ví dụ: ăn phở 40k rồi xem báo cáo tháng này), hệ thống đơn luồng dễ bỏ sót một trong hai hành động.
- Gợi ý trả lời:
  1. Hiện trạng thực tế tại Backend: Trường intent trong kết quả phân loại là một giá trị đơn, do đó hệ thống ưu tiên một ý định chính có trọng số cao nhất (nếu là Record thì lưu giao dịch, nếu là Action thì mở thẻ tính năng). Đối với câu chứa nhiều giao dịch chi tiêu cùng lúc (Multi-Record), Backend đã hỗ trợ mảng multi_records để lưu đầy đủ.
  2. Hướng nâng cấp tối ưu: Tái cấu trúc chỉ thị mô hình ngôn ngữ để trả về danh sách các tác vụ cần thực thi, kết hợp bộ điều phối chuỗi tại Backend để lưu giao dịch vào cơ sở dữ liệu trước rồi kích hoạt truy vấn báo cáo hiển thị cho người dùng.

Câu 7: Kỹ thuật tinh chỉnh LoRA cho mô hình ngôn ngữ lớn Qwen 2.5
- Vị trí logic: Mục phương pháp tinh chỉnh mô hình ngôn ngữ lớn tại chương 3.
- Điểm yếu tiềm ẩn: Tại sao không huấn luyện toàn bộ trọng số (Full Fine-tuning) mà lại chọn giải pháp tinh chỉnh tham số hiệu quả LoRA?
- Gợi ý trả lời: Thay vì tinh chỉnh toàn bộ hàng tỷ tham số gây tốn kém tài nguyên và dễ làm mất đi tri thức tổng quát của mô hình gốc, đề tài áp dụng LoRA để đóng băng mô hình nền tảng và chỉ huấn luyện thêm các ma trận biến đổi phụ có thứ hạng thấp. Nhờ đó, tốc độ huấn luyện nhanh hơn nhiều lần, tiết kiệm tối đa bộ nhớ GPU và tệp chuyển đổi xuất ra chỉ nặng vài chục megabyte, rất thuận tiện để lưu trữ và triển khai.

Câu 8: Lý do lựa chọn chỉ số Macro F1-Score thay vì Accuracy để đánh giá mô hình
- Vị trí logic: Các bảng đánh giá hiệu năng mô hình NLU và OCR tại chương 3.
- Điểm yếu tiềm ẩn: Đánh giá mô hình phân loại đa lớp chỉ dựa trên độ chính xác Accuracy sẽ phản ánh sai lệch hiệu quả thực tế khi tập dữ liệu bị mất cân bằng.
- Gợi ý trả lời: Dữ liệu chi tiêu thực tế có sự chênh lệch lớn giữa các danh mục (Ăn uống chiếm đa số mẫu, trong khi Y tế hay Giáo dục chiếm rất ít). Nếu dùng Accuracy, mô hình chỉ cần đoán thiên lệch vào nhãn chiếm số đông cũng đạt tỷ lệ phần trăm cao. Macro F1 tính điểm bình quân độc lập cho từng nhãn với trọng số ngang nhau, buộc mô hình phải nhận diện chính xác cả những danh mục hiếm.

### Nhóm 2: Nhận diện hóa đơn và thị giác máy tính

Câu 9: Bản chất con số 1.960 Support trên 116 ảnh hóa đơn kiểm thử LayoutLMv3
- Vị trí logic: Bảng 3.3 kết quả đánh giá mô hình LayoutLMv3 trên tập xác thực tại chương 3.
- Điểm yếu tiềm ẩn: Sự chênh lệch giữa số lượng 116 bức ảnh hóa đơn và 1.960 đơn vị Support dễ gây hiểu nhầm về quy mô tập kiểm thử.
- Gợi ý trả lời: Chỉ số Support trong bảng đánh giá đại diện cho tổng số lượng các từ và thực thể (Token-level count) thuộc các trường thông tin mục tiêu (Địa chỉ 489, Cửa hàng 333, Thời gian 355, Tổng tiền 783). Mỗi tờ hóa đơn chứa trung bình khoảng 17 từ thuộc các trường quan trọng này, và mô hình LayoutLMv3 được đánh giá chi tiết trên từng từ để đảm bảo không bỏ sót chữ trên hóa đơn.

Câu 10: Lý do lưu 1 hóa đơn thành 1 giao dịch tổng thay vì chia nhỏ từng món hàng
- Vị trí logic: Luồng xử lý dữ liệu hóa đơn sau khi quét OCR.
- Điểm yếu tiềm ẩn: Tại sao hệ thống không tự động bóc tách chi tiết từng dòng mặt hàng (Line-items) trên hóa đơn để tạo thành các giao dịch con tương ứng?
- Gợi ý trả lời:
  1. Hạn chế sai số tích lũy: Hóa đơn bán lẻ tại Việt Nam có bố cục không đồng nhất, phông chữ phức tạp và chứa nhiều dòng phụ (thuế VAT, giảm giá, chiết khấu). Việc cố gắng bóc tách từng món hàng rất dễ dẫn đến sai sót tích lũy khiến tổng tiền các món không khớp với số tiền thực tế người dùng đã trả.
  2. Phù hợp mục tiêu quản lý dòng tiền: Người dùng cá nhân cần ghi chép nhanh tổng tiền theo danh mục và hạn mức. Việc lưu 1 giao dịch tổng kết hợp lưu trữ ảnh chụp hóa đơn gốc trên Cloudflare R2 là giải pháp tối ưu: vừa đảm bảo số dư kế toán chuẩn xác 100%, vừa cho phép người dùng mở lại ảnh gốc để xem chi tiết từng món khi cần.

Câu 11: Cơ chế xử lý khi ảnh hóa đơn bị thiếu hoặc nhận diện sai số tiền
- Vị trí logic: Giao diện xác nhận hóa đơn và phân hệ xử lý giao dịch tại chương 3.
- Điểm yếu tiềm ẩn: Nếu ảnh chụp hóa đơn bị mờ, rách hoặc mất góc khiến OCR không trích xuất được số tiền, hệ thống có bắt người dùng chụp lại từ đầu hay không?
- Gợi ý trả lời:
  1. Không bắt chụp lại gây phiền toái: Hệ thống giữ lại toàn bộ các thông tin đã nhận diện đúng như ảnh bill, tên quán, danh mục và thời gian.
  2. Bật bảng nhập tiền trực tiếp: Tại màn hình xác nhận (CameraConfirmScreen), nếu số tiền nhỏ hơn hoặc bằng 0, ứng dụng tự động mở bảng trượt và trỏ con trỏ vào ô số tiền để người dùng điền bổ sung trong một giây.
  3. Cơ chế bản nháp: Nếu người dùng thoát ngang, giao dịch được lưu ở trạng thái chờ và hiển thị trên Thẻ cảnh báo giao dịch thiếu tiền tại Trang chủ để người dùng bấm vào bổ sung bất cứ lúc nào.

### Nhóm 3: Logic nghiệp vụ, kiến trúc hệ thống và bảo mật

Câu 12: Bản chất cơ chế RAG và lý do chọn Structured RAG trên cơ sở dữ liệu quan hệ
- Vị trí logic: Mục ứng dụng kiến trúc RAG vào hệ thống tư vấn tài chính tại chương 3.
- Điểm yếu tiềm ẩn: Việc truy xuất dữ liệu SQL từ cơ sở dữ liệu rồi nhúng vào câu lệnh prompt có được xem là RAG hay không, và tại sao không dùng cơ sở dữ liệu véc-tơ?
- Gợi ý trả lời:
  1. Khẳng định bản chất: Nhúng dữ liệu truy xuất từ cơ sở dữ liệu vào câu lệnh prompt chính là bản chất cốt lõi của RAG (Retrieval-Augmented Generation).
  2. Lý do chọn Structured RAG: Bài toán tài chính đòi hỏi sự chính xác tuyệt đối về mặt số học và cập nhật dữ liệu thời gian thực. Phương pháp Vector RAG chỉ tìm kiếm tương đồng gần đúng nên dễ gây sai lệch số dư, trong khi Structured RAG truy vấn SQL trực tiếp trên CockroachDB giúp số liệu luôn đúng tuyệt đối và tiết kiệm tài nguyên máy chủ.

Câu 13: Quy trình thanh toán nâng cấp tài khoản tự động qua VietQR và Webhook SePay
- Vị trí logic: Sơ đồ luồng tự động hóa và tích hợp cổng thanh toán tại chương 3.
- Điểm yếu tiềm ẩn: Làm thế nào hệ thống đối soát tự động người dùng nào vừa thanh toán mà không sợ tin tặc gửi yêu cầu giả mạo nâng cấp tài khoản?
- Gợi ý trả lời:
  1. Sinh mã đơn hàng và mã VietQR động: Backend tạo mã đơn hàng duy nhất và tạo mã VietQR có gắn sẵn số tài khoản, số tiền và nội dung chuyển khoản chứa mã đơn hàng đó.
  2. Bắt biến động số dư qua Webhook: Khi tiền vào tài khoản, SePay gửi Webhook kèm chữ ký số HMAC-SHA256 về máy chủ Backend.
  3. Đối soát và kích hoạt tức thì: Backend xác thực chữ ký số bảo mật, trích xuất mã đơn hàng từ nội dung chuyển khoản, kiểm tra khớp số tiền trong CockroachDB và cập nhật cờ is_premium = true, sau đó gửi thông báo đẩy FCM xuống thiết bị để mở khóa tính năng cho người dùng.

Câu 14: Cơ chế tự động khóa tài khoản (Auto Ban) và quy trình khiếu nại
- Vị trí logic: Tầng trung gian bảo mật và bảng quản lý người dùng tại trang quản trị Web Admin.
- Điểm yếu tiềm ẩn: Hệ thống phát hiện và ngăn chặn hành vi lạm dụng hoặc phá hoại của người dùng như thế nào?
- Gợi ý trả lời:
  1. Khóa do lạm dụng tần suất: Tầng trung gian theo dõi số lượng yêu cầu của từng người dùng theo cửa sổ trượt 1 phút. Nếu vượt quá 60 yêu cầu/phút, hệ thống tự động khóa tài khoản với lý do spam và gửi email thông báo.
  2. Khóa do vi phạm tiêu chuẩn cộng đồng: Tự động kiểm duyệt nội dung tin nhắn chat/NLU, nếu phát hiện từ ngữ thù địch hoặc xúc phạm nghiêm trọng thì lập tức khóa tài khoản.
  3. Quy trình khiếu nại: Người dùng bị khóa có thể gửi đơn khiếu nại từ màn hình đăng nhập để người quản trị xem xét và bấm duyệt mở khóa trên Web Admin.

Câu 15: Nền tảng công cụ gán nhãn và cơ sở của ngưỡng 10.000 mẫu NLU / 1.000 ảnh OCR
- Vị trí logic: Bảng điều khiển MLOps và trang huấn luyện lại mô hình trên Web Admin.
- Điểm yếu tiềm ẩn: Công cụ gán nhãn được xây dựng bằng cách nào và dựa vào đâu để đặt ngưỡng sẵn sàng tái huấn luyện là 10.000 giao dịch và 1.000 ảnh?
- Gợi ý trả lời:
  1. Công cụ gán nhãn tự lập trình: Giao diện gán nhãn hóa đơn BillLabelCanvas được tự viết hoàn toàn bằng React và HTML5 Canvas, hỗ trợ kéo vẽ khung tọa độ, co giãn 8 điểm neo và tích hợp AI gán nhãn bán tự động (Pre-labeling).
  2. Cơ sở của ngưỡng kích hoạt: Căn cứ vào quy mô của tập huấn luyện gốc giúp mô hình hội tụ ban đầu (1.159 ảnh MC-OCR và 14.000 mẫu NLU) kết hợp điểm uốn của đường cong học tập (Learning Curve). Đây là các tham số cấu hình mở để thông báo cho quản trị viên biết khi nào dữ liệu đã đủ độ dày thống kê để tiến hành bấm nút huấn luyện lại.
