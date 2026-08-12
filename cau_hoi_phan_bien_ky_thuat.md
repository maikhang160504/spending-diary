Dựa trên quá trình phân tích tài liệu báo cáo luận văn, tài liệu ghi chú sửa lỗi và kiến trúc phần mềm, hội đồng phản biện đưa ra 12 câu hỏi chất vấn chuyên sâu nhằm đánh giá năng lực giải quyết các bài toán kỹ thuật cốt lõi trong hệ thống quản lý chi tiêu.

### Nhóm 1: Logic nghiệp vụ và thuật toán

Câu 1: Xử lý xung đột đồng thời trong ví nhóm
- Vị trí logic: Đoạn đề cập đến hạn chế của tính năng ví nhóm ở phần kết luận và sơ đồ luồng tham gia ví chung.
- Điểm yếu tiềm ẩn: Khi nhiều thành viên thao tác thêm, sửa hoặc xóa giao dịch cùng một thời điểm, hệ quản trị cơ sở dữ liệu CockroachDB nếu chỉ thực hiện thao tác đọc và ghi tuần tự mà không có cơ chế khóa lock sẽ dẫn đến hiện tượng ghi đè dữ liệu lost update. Hậu quả là số dư của ví nhóm bị tính toán sai lệch hoàn toàn so với thực tế.
- Gợi ý trả lời: Cần trình bày việc áp dụng cơ chế kiểm soát đồng thời lạc quan optimistic concurrency control bằng cách thêm trường phiên bản version vào bảng dữ liệu ví tiền. Mỗi lần cập nhật, hệ thống sẽ kiểm tra đối chiếu phiên bản hiện tại, nếu phát hiện xung đột thì từ chối giao dịch và yêu cầu người dùng tải lại số liệu mới nhất. Hoặc có thể ứng dụng mức độ cô lập giao dịch tuần tự hóa serializable transactions của CockroachDB kết hợp với vòng lặp thử lại tự động ở tầng backend Node.js.

Câu 2: Xử lý nhiều giao dịch trong một câu lệnh ngôn ngữ tự nhiên
- Vị trí logic: Lỗi hai giao dịch trong một tin nhắn được liệt kê tại tài liệu ghi chú sửa lỗi.
- Điểm yếu tiềm ẩn: Kiến trúc nhận diện ý định hai tầng PhoBERT và Qwen hiện tại được tối ưu để bóc tách một thực thể cho mỗi câu lệnh. Khi người dùng nhập một câu dài chứa nhiều khoản chi tiêu, ví dụ sáng ăn phở 40k, trưa đổ xăng 50k, hệ thống phân loại ý định ở tầng một dễ dàng bỏ sót thông tin, khiến tầng hai phân tích sai cấu trúc và làm mất mát dữ liệu giao dịch của người dùng.
- Gợi ý trả lời: Khẳng định sự cần thiết của việc tái cấu trúc lại câu lệnh nền tảng system prompt để yêu cầu mô hình ngôn ngữ trả về định dạng mảng các đối tượng array of objects thay vì một đối tượng đơn lẻ. Đồng thời, tầng PhoBERT cần được tinh chỉnh bổ sung nhãn đa ý định multi-record để phân luồng chính xác các câu nói chứa nhiều khoản chi phức tạp.

Câu 3: Hiện tượng phá vỡ định dạng cấu trúc dữ liệu của mô hình ngôn ngữ
- Vị trí logic: Lỗi phân tích cú pháp JSON thất bại khi mô hình sinh ra đoạn văn bản hội thoại được trích xuất từ log hệ thống.
- Điểm yếu tiềm ẩn: Việc ép buộc một mô hình ngôn ngữ vừa phải đóng vai trò là một trợ lý vui vẻ, dùng từ lóng, vừa phải làm nhiệm vụ bóc tách dữ liệu JSON nghiêm ngặt trong cùng một lượt xử lý là một thiết kế sai lầm. Sự xung đột về chỉ thị này khiến mô hình dễ dàng sinh ra ảo giác, trả về văn bản tự do và làm sập toàn bộ luồng xử lý trích xuất thông số của backend.
- Gợi ý trả lời: Đề xuất giải pháp chia tách mối quan tâm. Luồng thứ nhất sử dụng mô hình với nhiệt độ temperature bằng không chuyên biệt để trích xuất JSON. Luồng thứ hai chạy độc lập với nhiệt độ cao hơn để sinh câu thoại tương tác tự nhiên. Hai luồng này được gọi song song để vừa đảm bảo tính chính xác của dữ liệu vừa giữ được trải nghiệm giao tiếp thân thiện.

Câu 4: Tính lũy đẳng trong giao dịch qua mạng chập chờn
- Vị trí logic: Yêu cầu phi chức năng về việc chống tạo trùng lặp bản ghi trong trường hợp đường truyền mạng gián đoạn.
- Điểm yếu tiềm ẩn: Khi ứng dụng trên điện thoại gửi yêu cầu lưu chi tiêu, backend đã lưu thành công nhưng mạng bị rớt trước khi trả về kết quả. Ứng dụng sẽ tự động gửi lại yêu cầu khi có mạng, dẫn đến việc tạo ra hai giao dịch giống hệt nhau. Kiến trúc hệ thống hiện tại chưa đề cập rõ cách phòng chống vấn đề này bằng mã định danh luồng.
- Gợi ý trả lời: Trình bày cơ chế khóa lũy đẳng idempotency key. Ứng dụng di động tự sinh ra một mã định danh duy nhất UUID cho mỗi lần bấm lưu và gửi kèm trên tiêu đề yêu cầu header. Backend sẽ kiểm tra mã này trong bộ nhớ đệm Redis hoặc cơ sở dữ liệu, nếu trùng khớp trong khoảng thời gian ngắn thì sẽ bỏ qua yêu cầu thứ hai và trả về kết quả thành công ngay lập tức.

### Nhóm 2: Thiết kế kiến trúc và chất lượng mã nguồn

Câu 5: Nghẽn cổ chai do kỹ thuật truy vấn liên tục trong thanh toán
- Vị trí logic: Sơ đồ thuật toán thanh toán nâng cấp tài khoản qua VNPay bằng kỹ thuật vòng lặp chạy ngầm polling.
- Điểm yếu tiềm ẩn: Việc ứng dụng di động liên tục gọi API hai giây một lần lên máy chủ Node.js để kiểm tra trạng thái thanh toán là một thiết kế kém hiệu quả. Cách làm này gây lãng phí tài nguyên kết nối và dễ dàng đánh sập máy chủ DDoS nội bộ nếu có lượng lớn người dùng cùng lúc nâng cấp tài khoản, trong khi hệ thống vốn dĩ đã có sẵn kết nối WebSocket theo thời gian thực.
- Gợi ý trả lời: Phương án tối ưu là ứng dụng chỉ cần duy trì kết nối WebSocket. Khi cổng thanh toán VNPay gửi webhook báo giao dịch thành công về máy chủ, Node.js sẽ chủ động đẩy thông báo qua WebSocket xuống thiết bị để cập nhật giao diện lập tức, triệt tiêu hoàn toàn sự lãng phí từ việc truy vấn liên tục.

Câu 6: Suy giảm hiệu năng khi phân trang trên cơ sở dữ liệu phân tán
- Vị trí logic: Chức năng hiển thị danh sách lịch sử giao dịch.
- Điểm yếu tiềm ẩn: Đối với các hệ quản trị cơ sở dữ liệu phân tán như CockroachDB, việc sử dụng cơ chế phân trang dựa trên độ lệch limit và offset sẽ trở thành thảm họa hiệu năng khi người dùng cuộn xem các giao dịch cũ. Nút điều phối sẽ phải quét và loại bỏ hàng chục ngàn bản ghi qua nhiều phân mảnh mạng trước khi trả về kết quả, khiến tốc độ tải trang chậm dần theo độ sâu của danh sách.
- Gợi ý trả lời: Đề xuất chuyển đổi sang phương pháp phân trang dựa trên con trỏ cursor-based pagination. Hệ thống sẽ sử dụng mốc thời gian tạo hoặc mã định danh của giao dịch cuối cùng trong danh sách làm điều kiện truy vấn cho trang tiếp theo, ví dụ where id nhỏ hơn last_id. Cách này tận dụng tối đa chỉ mục của cơ sở dữ liệu và giữ tốc độ truy vấn luôn ổn định.

Câu 7: Rủi ro rác dữ liệu lưu trữ do luồng xử lý ảnh hóa đơn
- Vị trí logic: Sơ đồ luồng hoạt động quét và nén ảnh hóa đơn tải lên Cloudflare R2.
- Điểm yếu tiềm ẩn: Nếu người dùng chụp ảnh hóa đơn, tải lên đám mây thành công nhưng sau đó bấm nút hủy ở màn hình xác nhận thay vì lưu giao dịch, bức ảnh đó vẫn tồn tại vĩnh viễn trên kho lưu trữ R2. Theo thời gian, lượng dữ liệu mồ côi này sẽ phình to và tiêu tốn chi phí bảo trì không cần thiết.
- Gợi ý trả lời: Thiết lập vòng đời luân chuyển tệp tin. Hình ảnh mới tải lên sẽ nằm ở thư mục tạm thời trên đám mây với quy tắc vòng đời tự động xóa sau 24 giờ. Chỉ khi giao dịch thực sự được xác nhận lưu vào CockroachDB, backend mới tiến hành di chuyển hình ảnh sang thư mục lưu trữ chính thức.

Câu 8: Điểm thắt cổ chai về độ trễ trải nghiệm của mô hình ngôn ngữ lớn
- Vị trí logic: Bảng đánh giá hiệu năng bóc tách danh mục, ghi nhận độ trễ của Qwen lên tới hơn 9 giây.
- Điểm yếu tiềm ẩn: Việc bắt người dùng chờ gần 10 giây cho một tin nhắn phản hồi trên di động sẽ phá hủy hoàn toàn trải nghiệm tương tác mượt mà. Hơn nữa, việc giữ một luồng kết nối API treo trong 10 giây sẽ làm cạn kiệt tài nguyên của máy chủ Node.js nếu có nhiều người cùng gửi tin nhắn.
- Gợi ý trả lời: Ứng dụng mô hình giao tiếp bất đồng bộ. Khi nhận tin nhắn, Node.js trả về ngay mã giao tiếp và đóng kết nối HTTP để giải phóng tài nguyên. Ứng dụng di động hiển thị trạng thái đang nhập chữ. Trong khi đó, máy chủ AI xử lý ngầm, hoàn tất sẽ gọi lại Node.js để đẩy kết quả qua WebSocket xuống điện thoại. Song song đó, cần đề xuất kỹ thuật lượng tử hóa quantization để nén mô hình, giảm độ trễ xử lý xuống mức thấp nhất.

### Nhóm 3: Bảo mật và tối ưu hóa

Câu 9: Lỗ hổng tấn công từ chối dịch vụ thông qua cơ chế cấm tự động
- Vị trí logic: Bảng kết quả kiểm thử chức năng xử lý ngầm, phần cơ chế giới hạn tần suất phát hiện và khóa kết nối lập tức.
- Điểm yếu tiềm ẩn: Nếu hệ thống chặn trực tiếp mã định danh tài khoản khi phát hiện lưu lượng truy cập cao, kẻ tấn công chỉ cần lấy cắp mã thông báo truy cập cũ hoặc biết được mã định danh của một người dùng bất kỳ để spam API. Cơ chế này vô tình tiếp tay cho kẻ xấu khóa oan tài khoản của nạn nhân mà người đó không hề hay biết.
- Gợi ý trả lời: Cơ chế giới hạn tần suất phải được áp dụng dựa trên địa chỉ IP hoặc định danh thiết bị vật lý để chặn nguồn tấn công trước. Đối với mã định danh tài khoản, thay vì cấm vĩnh viễn, hệ thống chỉ nên áp dụng hình phạt đóng băng tạm thời cooldown để bảo vệ quyền lợi của người dùng chân chính, kết hợp lưu vết log để quản trị viên đánh giá.

Câu 10: Rủi ro tiêm mã độc vào chỉ thị hệ thống qua cơ chế truy xuất
- Vị trí logic: Sơ đồ luồng xử lý câu hỏi tư vấn tài chính theo kiến trúc RAG, phần nhúng số liệu vào chỉ thị hệ thống.
- Điểm yếu tiềm ẩn: Cơ chế RAG sẽ truy xuất các ghi chú giao dịch do chính người dùng nhập và ghép thẳng vào câu lệnh nền tảng của mô hình ngôn ngữ. Nếu một giao dịch chứa dòng ghi chú ác ý mang tính thao túng prompt injection, mô hình Qwen sẽ bị đánh lừa và dễ dàng tiết lộ các bí mật nghiệp vụ nội bộ ra bên ngoài.
- Gợi ý trả lời: Cần trình bày quy trình làm sạch dữ liệu đầu vào. Nội dung lịch sử giao dịch phải được tách biệt hoàn toàn khỏi các lệnh điều khiển bằng hệ thống dấu phân cách rõ ràng. Đồng thời, cần bổ sung quy tắc phòng thủ ở cuối câu lệnh để ra lệnh cho AI tuyệt đối không được thực thi bất kỳ lời nhắc nào nằm trong khối văn bản dữ liệu giao dịch.

Câu 11: Lỗ hổng trong quy trình thu hồi mã thông báo không trạng thái
- Vị trí logic: Cơ chế khóa tài khoản có hiệu lực tức thời thông qua thu hồi mã xác thực được đề cập ở bảng đặc tả quản lý người dùng.
- Điểm yếu tiềm ẩn: Bản chất của mã thông báo JSON Web Token là không lưu trạng thái stateless, nghĩa là máy chủ Node.js không cần kiểm tra cơ sở dữ liệu khi xác thực. Do đó, lời khẳng định thu hồi tức thời là mâu thuẫn. Nếu không có danh sách chặn blacklist, người dùng bị khóa vẫn có thể tiếp tục sử dụng ứng dụng bằng mã thông báo cũ cho đến khi nó tự hết hạn.
- Gợi ý trả lời: Giải quyết mâu thuẫn bằng cách triển khai danh sách đen trên Redis để lưu lại các mã thông báo bị vô hiệu hóa với thời gian tồn tại bằng đúng thời hạn của mã đó. Máy chủ sẽ kiểm tra nhanh Redis trước khi duyệt. Hoặc sử dụng kiến trúc mã thông báo đôi, trong đó mã truy cập access token có thời hạn cực ngắn khoảng vài phút, khi khóa tài khoản chỉ cần hủy mã làm mới refresh token ở cơ sở dữ liệu.

Câu 12: Thông báo rác từ cơ chế dự phòng kép
- Vị trí logic: Sơ đồ luồng xử lý thông báo theo cơ chế dự phòng kép kết hợp thông báo nội bộ và thông báo đẩy.
- Điểm yếu tiềm ẩn: Việc gửi song song thông báo qua cả WebSocket và hệ thống đám mây Firebase sẽ gây phiền toái. Nếu ứng dụng đang chạy ngầm nhưng kết nối mạng WebSocket chưa kịp ngắt, điện thoại của người dùng sẽ hiển thị hai thông báo trùng lặp cho cùng một sự kiện, gây rác màn hình và giảm tính chuyên nghiệp của hệ thống.
- Gợi ý trả lời: Bổ sung cơ chế loại bỏ trùng lặp deduplication trên thiết bị di động thông qua một mã định danh thông báo duy nhất. Ngoài ra, thay vì đẩy song song lập tức, máy chủ Node.js nên đợi khoảng hai giây, nếu không nhận được tín hiệu hồi đáp ack từ WebSocket chứng tỏ ứng dụng đã đóng, thì lúc đó mới quyết định gửi thông báo qua kênh Firebase.
