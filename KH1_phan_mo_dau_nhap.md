# BẢN NHÁP KẾ HOẠCH 1: PHẦN MỞ ĐẦU (để bạn duyệt)

> [!NOTE]
> Dưới đây là bản nháp viết lại toàn bộ **Phần mở đầu** — từ Tóm tắt đến hết Bố cục luận văn. Sau khi bạn duyệt, tôi sẽ áp dụng vào file `Luan_van_Hoan_chinh.md`.

---

## TÓM TẮT ĐỀ TÀI

Quản lý tài chính cá nhân là một kỹ năng thiết yếu trong cuộc sống hiện đại. Tuy nhiên, hầu hết các ứng dụng quản lý chi tiêu hiện nay đều yêu cầu người dùng nhập liệu thủ công qua biểu mẫu tĩnh, gây ra sự nhàm chán và mất thời gian. Đề tài này xây dựng **Spending Diary** — một ứng dụng quản lý chi tiêu cá nhân thông minh, cho phép người dùng ghi chép chi tiêu chỉ bằng cách nhắn tin tự nhiên hoặc chụp ảnh hóa đơn.

Hệ thống tích hợp trợ lý ảo AI tên **Mimo**, giúp người dùng nhập chi tiêu qua đoạn hội thoại thay vì điền biểu mẫu. Ứng dụng sử dụng mô hình **PhoBERT** và **Qwen 2.5** để hiểu ngôn ngữ tiếng Việt tự nhiên (bao gồm cả tiếng lóng, từ viết tắt), đồng thời kết hợp **VietOCR** và **LayoutLMv3** để tự động nhận dạng và trích xuất thông tin từ ảnh hóa đơn bán lẻ. Để đảm bảo số liệu tài chính luôn chính xác, hệ thống áp dụng cơ chế buộc AI phải truy vấn dữ liệu thực từ cơ sở dữ liệu trước khi trả lời, thay vì tự đoán và đưa ra thông tin sai lệch.

Ứng dụng được xây dựng trên kiến trúc nhiều dịch vụ độc lập, bao gồm ứng dụng di động đa nền tảng bằng Flutter và cổng quản trị web bằng React. Đánh giá thực nghiệm cho thấy mô hình hiểu ngôn ngữ đạt Macro F1-Score trên 96% với thời gian phản hồi thấp. Spending Diary không chỉ là một công cụ ghi chép đơn thuần, mà còn mang lại trải nghiệm tương tác tự nhiên, giúp người dùng dễ dàng theo dõi và quản lý tài chính cá nhân hàng ngày.

---

## LỜI CẢM ƠN

Để hoàn thành đề tài luận văn này, trước hết em xin gửi lời cảm ơn chân thành và sâu sắc đến gia đình — những người đã luôn ủng hộ, động viên và tạo mọi điều kiện tốt nhất để em có thể tập trung vào việc học tập và nghiên cứu trong suốt những năm đại học.

Em xin bày tỏ lòng biết ơn đặc biệt đến **Thầy Thái Minh Tuấn** — Giảng viên hướng dẫn — đã tận tình chỉ bảo, định hướng và hỗ trợ em trong suốt quá trình thực hiện đề tài. Những chia sẻ kinh nghiệm và góp ý chuyên môn của Thầy là nguồn động lực lớn giúp em vượt qua các khó khăn kỹ thuật trong quá trình xây dựng hệ thống.

Em cũng xin cảm ơn các bạn đã đồng hành, hỗ trợ em trong quá trình thu thập dữ liệu, kiểm thử hệ thống và đóng góp ý kiến phản hồi về trải nghiệm người dùng:

- **Dương Quốc Kiệt**
- **Thạch Ly Na**
- **Hà Nhã Uyên**
- **Thạch Thị Bảo Trân**
- **Lâm Thị Bích Như**

Sự giúp đỡ nhiệt tình của các bạn đã giúp đề tài đạt được kết quả thực nghiệm có giá trị và sát với nhu cầu thực tế.

Mặc dù đã cố gắng hết sức, đề tài chắc chắn không tránh khỏi những thiếu sót. Em rất mong nhận được sự góp ý từ quý Thầy Cô trong Hội đồng để tiếp tục hoàn thiện trong tương lai.

*Trân trọng cảm ơn!*

---

## PHẦN GIỚI THIỆU

### 1. Đặt vấn đề

Trong cuộc sống hiện đại, việc quản lý tài chính cá nhân đóng vai trò rất quan trọng đối với sự ổn định kinh tế của mỗi người. Trên thị trường hiện nay đã có nhiều ứng dụng hỗ trợ quản lý chi tiêu như MoneyLover, MISA hay Timo, tuy nhiên các ứng dụng này vẫn còn một hạn chế chung: người dùng phải tự tay nhập từng khoản chi tiêu qua các biểu mẫu cố định. Việc lặp đi lặp lại thao tác điền số tiền, chọn danh mục, ghi chú cho mỗi giao dịch khiến người dùng dần cảm thấy mệt mỏi và cuối cùng bỏ cuộc sau một thời gian ngắn sử dụng.

Sự phát triển mạnh mẽ của trí tuệ nhân tạo, đặc biệt là xử lý ngôn ngữ tự nhiên và thị giác máy tính, đã mở ra hướng đi mới cho bài toán này. Các mô hình như PhoBERT có khả năng hiểu được ý nghĩa câu nói tiếng Việt, trong khi VietOCR có thể nhận dạng chữ trên ảnh chụp hóa đơn. Tuy nhiên, việc tích hợp các mô hình AI vào một ứng dụng thực tế vẫn gặp nhiều thách thức, nhất là khi phải xử lý sự đa dạng của ngôn ngữ tiếng Việt — bao gồm tiếng lóng, từ viết tắt, cách nói vùng miền — cùng với sự phức tạp về bố cục của các loại hóa đơn khác nhau.

Xuất phát từ những vấn đề thực tiễn trên, đề tài này hướng đến việc xây dựng **Spending Diary** — một ứng dụng quản lý chi tiêu cá nhân thông minh, cho phép người dùng ghi chép chi tiêu chỉ bằng cách nhắn tin hoặc chụp ảnh hóa đơn, thay vì phải điền biểu mẫu thủ công.

### 2. Những nghiên cứu liên quan

Để xác định rõ khoảng trống mà đề tài hướng tới giải quyết, em đã khảo sát hai nhóm giải pháp hiện có: các ứng dụng quản lý tài chính phổ biến trên thị trường và các công trình nghiên cứu AI liên quan.

Về nhóm ứng dụng quản lý tài chính, **MoneyLover** (https://moneylover.me) và **Sổ thu chi MISA** (https://www.misa.vn) là hai ứng dụng được sử dụng rộng rãi tại Việt Nam. Cả hai đều cung cấp hệ thống báo cáo trực quan, hỗ trợ nhiều loại ví và danh mục chi tiêu. Tuy nhiên, việc phân loại giao dịch của chúng chủ yếu dựa vào từ khóa cố định, dẫn đến nhận diện sai khi người dùng sử dụng tiếng lóng hoặc từ viết tắt. Đồng thời, việc nhập liệu vẫn hoàn toàn phụ thuộc vào biểu mẫu tĩnh. Ở một hướng tiếp cận khác, **Timo** (https://timo.vn) và các ngân hàng số thế hệ mới có khả năng phân loại giao dịch chính xác nhờ mã ngành hàng từ đơn vị thanh toán, nhưng lại không theo dõi được các giao dịch bằng tiền mặt hay chuyển khoản trực tiếp giữa cá nhân, và cũng chưa có trợ lý tài chính có khả năng hiểu ngữ cảnh.

Về nhóm nghiên cứu AI, cuộc thi MC-OCR Challenge 2021 đã chứng minh hiệu quả của các mô hình học sâu trong việc nhận dạng hóa đơn tiếng Việt, tuy nhiên các giải pháp này chưa được tích hợp vào một ứng dụng hoàn chỉnh phục vụ người dùng cuối. Mô hình PhoBERT đã đánh dấu bước tiến lớn cho việc xử lý ngôn ngữ tự nhiên tiếng Việt, trong khi các mô hình ngôn ngữ lớn thế hệ mới có khả năng suy luận vượt trội nhưng đi kèm chi phí tính toán cao và rủi ro đưa ra thông tin sai lệch khi tư vấn về tài chính.

Từ phân tích trên, Spending Diary ra đời nhằm giải quyết đồng thời ba vấn đề: tự động hóa nhập liệu bằng cách kết hợp hiểu ngôn ngữ tự nhiên và nhận dạng hóa đơn; đảm bảo độ tin cậy của số liệu tài chính bằng cách buộc AI luôn dựa vào dữ liệu thực; và tích hợp toàn bộ vào một hệ thống hoàn chỉnh với khả năng cá nhân hóa cho từng người dùng.

### 3. Mục tiêu đề tài

**Mục tiêu tổng quát:** Đề tài hướng đến việc nghiên cứu, thiết kế và xây dựng hệ thống **Spending Diary** — một ứng dụng quản lý chi tiêu cá nhân thông minh tích hợp trí tuệ nhân tạo. Mục tiêu chính là giúp người dùng ghi chép chi tiêu một cách nhanh chóng và tự nhiên thông qua hội thoại hoặc ảnh chụp hóa đơn, thay vì phải điền biểu mẫu thủ công. Đồng thời, hệ thống cung cấp các báo cáo phân tích và gợi ý chi tiêu để giúp người dùng quản lý tài chính hiệu quả hơn.

**Mục tiêu cụ thể:** Để thực hiện mục tiêu trên, đề tài được chia thành năm mục tiêu cụ thể.

Thứ nhất, xây dựng khả năng tiếp nhận dữ liệu từ nhiều nguồn. Hệ thống cho phép người dùng ghi chép chi tiêu bằng cách nhắn tin mô tả bằng lời, hoặc chụp ảnh hóa đơn bán lẻ. Cả hai phương thức đều được xử lý tại cùng một màn hình trò chuyện với trợ lý Mimo, giúp trải nghiệm đơn giản và nhanh chóng.

Thứ hai, nghiên cứu và triển khai các mô hình AI chuyên biệt cho hai luồng xử lý chính. Với luồng hiểu ngôn ngữ, đề tài tinh chỉnh mô hình PhoBERT và Qwen 2.5 trên dữ liệu tiếng Việt để nhận diện chính xác ý định người dùng và trích xuất thông tin chi tiêu từ câu nói tự nhiên, kể cả khi có tiếng lóng hay từ viết tắt. Với luồng nhận dạng hóa đơn, đề tài kết hợp DBNet, VietOCR và LayoutLMv3 để phát hiện vùng chữ, nhận dạng ký tự tiếng Việt và trích xuất các thông tin quan trọng như tên cửa hàng, ngày giao dịch và tổng tiền.

Thứ ba, xây dựng cơ chế đảm bảo độ chính xác khi AI tư vấn tài chính. Khi người dùng hỏi về tình hình chi tiêu, hệ thống buộc AI phải truy vấn dữ liệu thực từ cơ sở dữ liệu trước khi trả lời, thay vì tự suy đoán. Ngoài ra, khi có sự khác biệt giữa kết quả AI đề xuất và thực tế, người dùng luôn có quyền chỉnh sửa, và lịch sử chỉnh sửa này được lưu lại để cải thiện mô hình sau này.

Thứ tư, xây dựng hệ thống quản lý ngân sách và gợi ý chi tiêu. Hệ thống cho phép người dùng đặt hạn mức cho từng danh mục, theo dõi mục tiêu tiết kiệm, và nhận cảnh báo khi chi tiêu vượt ngưỡng. Trợ lý Mimo sẽ phản hồi bằng các biểu cảm khác nhau tùy thuộc vào tình hình tài chính, giúp tạo động lực kiểm soát chi tiêu.

Thứ năm, xây dựng hệ thống hoàn chỉnh bao gồm ứng dụng di động đa nền tảng bằng Flutter với nhiều chế độ xem linh hoạt, cổng quản trị web bằng React để giám sát và kiểm duyệt dữ liệu AI, và kiến trúc dịch vụ backend có khả năng mở rộng với cơ sở dữ liệu phân tán đảm bảo tính toàn vẹn dữ liệu tài chính.

### 4. Đối tượng và phạm vi nghiên cứu

Đề tài hướng đến hai nhóm đối tượng chính. Về phía người dùng, ứng dụng được thiết kế cho các cá nhân có nhu cầu theo dõi và quản lý thu chi hàng ngày, đặc biệt là người trẻ tại Việt Nam — những người quen thuộc với việc sử dụng điện thoại thông minh và sẵn sàng trải nghiệm các ứng dụng công nghệ mới trong đời sống. Về phía công nghệ, đề tài tập trung nghiên cứu các mô hình học sâu phục vụ xử lý ngôn ngữ tự nhiên tiếng Việt (PhoBERT, Qwen 2.5) và nhận dạng tài liệu (DBNet, VietOCR, LayoutLMv3), cùng với kiến trúc hệ thống phân tán sử dụng CockroachDB và cơ chế truy xuất dữ liệu cho AI để đảm bảo độ tin cậy khi tư vấn tài chính.

Về phạm vi, đề tài giới hạn ở việc xử lý hóa đơn bán lẻ tại Việt Nam và ngôn ngữ tiếng Việt tự nhiên trong phạm vi các danh mục chi tiêu cá nhân phổ biến. Đề tài tập trung tinh chỉnh và tích hợp các mô hình AI hiện đại, không xây dựng kiến trúc mạng học sâu từ đầu. Về mặt nghiệp vụ, hệ thống chỉ phục vụ bài toán quản lý ngân sách và phân tích chi tiêu cá nhân hoặc nhóm nhỏ, không mở rộng sang kế toán doanh nghiệp hay phân tích đầu tư.

### 5. Phương pháp nghiên cứu

Về phương pháp xây dựng dữ liệu, đề tài xây dựng tập dữ liệu huấn luyện cho mô hình hiểu ngôn ngữ bằng cách kết hợp viết mẫu câu thủ công và sử dụng mô hình ngôn ngữ lớn để sinh thêm các biến thể tự nhiên, đạt tổng cộng hơn 127.000 mẫu câu gốc. Dữ liệu được chuẩn hóa tiếng lóng, tách từ tiếng Việt và chia tập theo tỷ lệ cân bằng giữa các nhãn. Đối với dữ liệu hóa đơn, đề tài kế thừa tập dữ liệu chuẩn MC-OCR 2021 kết hợp với ảnh hóa đơn thực tế thu thập từ người dùng, được tiền xử lý bằng các kỹ thuật tăng tương phản, căn chỉnh độ nghiêng và chuẩn hóa độ phân giải.

Về phương pháp xây dựng và đánh giá mô hình AI, đề tài thực hiện so sánh hiệu năng giữa ba kiến trúc mô hình: phương pháp thống kê truyền thống TF-IDF làm nền tảng đối sánh, mô hình PhoBERT tinh chỉnh trên dữ liệu tiếng Việt, và mô hình ngôn ngữ lớn Qwen 2.5 tinh chỉnh bằng kỹ thuật LoRA. Với luồng nhận dạng hóa đơn, đề tài đánh giá kết hợp VietOCR cho nhận dạng chữ và LayoutLMv3 cho trích xuất thông tin, so sánh với phương pháp truyền thống dùng từ khóa và biểu thức chính quy. Kết quả được đo bằng các chỉ số chuẩn: F1-Score cho phân loại, tỷ lệ lỗi ký tự cho nhận dạng chữ.

Về phương pháp phát triển phần mềm và kiểm thử, đề tài áp dụng quy trình phát triển linh hoạt, chia hệ thống thành các dịch vụ độc lập được đóng gói riêng biệt. Kiểm thử bao gồm kiểm thử đơn vị cho các chức năng cốt lõi, kiểm thử khả năng chịu tải của máy chủ, và kiểm thử tính toàn vẹn dữ liệu để đảm bảo không xảy ra lỗi ghi trùng giao dịch.

### 6. Bố cục luận văn

Luận văn được chia thành ba phần chính với cấu trúc như sau:

**Phần 1: Giới thiệu** — trình bày tổng quan bao gồm đặt vấn đề, mục tiêu, đối tượng và phạm vi, phương pháp nghiên cứu và bố cục luận văn.

**Phần 2: Nội dung nghiên cứu và triển khai** — gồm bốn chương:
- **Chương 1** trình bày tổng quan đề tài, mô tả hệ thống, phân tích yêu cầu chức năng và phi chức năng.
- **Chương 2** trình bày cơ sở lý thuyết và các công nghệ được sử dụng trong hệ thống.
- **Chương 3** trình bày thiết kế kiến trúc và cài đặt hệ thống theo 4 tầng, đi kèm kết quả đánh giá các mô hình AI.
- **Chương 4** trình bày kiểm thử chức năng, kiểm thử phi chức năng và đánh giá tổng thể hệ thống.

**Phần 3: Kết luận và hướng phát triển** — tổng kết các kết quả đạt được, nêu hạn chế và đề xuất hướng phát triển trong tương lai.

**Tài liệu tham khảo và Phụ lục** — bao gồm danh mục tài liệu tham chiếu, đặc tả Use Case chi tiết, sơ đồ cơ sở dữ liệu đầy đủ, cấu trúc AI System Prompt và danh mục giao diện hệ thống.

---

> [!IMPORTANT]
> **Bạn hãy xem lại bản nháp trên và cho biết:**
> 1. Nội dung có chính xác và đầy đủ không?
> 2. Giọng văn đã tự nhiên và phù hợp chưa?
> 3. Có phần nào cần điều chỉnh thêm không?
>
> Sau khi bạn đồng ý, tôi sẽ áp dụng vào file luận văn chính.
