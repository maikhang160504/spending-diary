### Chức năng Chia Bill Nhóm

Chức năng Chia Bill thuộc nhóm công cụ tiền tệ của hệ thống, cho phép nhiều người cùng ghi nhận các khoản chi tiêu chung, tính toán công nợ giữa các thành viên và hỗ trợ lưu phần chi phí thực tế vào ví cá nhân của từng người dùng.

#### 1. Tạo nhóm chia bill

Người dùng có thể tạo một nhóm chia bill mới bằng cách nhập:

- Tên nhóm.
- Danh sách thành viên tham gia.
- Mô tả nhóm (tùy chọn).

Sau khi tạo thành công, hệ thống sinh ra một mã tham gia nhóm duy nhất để người dùng mời các thành viên khác tham gia.

#### 2. Tham gia nhóm bằng mã

Người dùng có thể tham gia một nhóm chia bill bằng cách nhập mã nhóm được cung cấp bởi người tạo nhóm.

Sau khi tham gia:

- Hệ thống hiển thị danh sách thành viên hiện có trong nhóm.
- Người dùng có thể chọn một thành viên đã tồn tại trong danh sách để liên kết với tài khoản của mình.
- Nếu tên của người dùng chưa tồn tại trong nhóm, người dùng có thể tạo thêm thành viên mới.
- Một thành viên chỉ được liên kết với một tài khoản duy nhất.
- Không cho phép nhiều tài khoản liên kết với cùng một thành viên.
- Những thành viên không được liên kết với tài khoản vẫn được giữ lại trong nhóm để phục vụ việc chia bill cho những người không sử dụng ứng dụng.

Nhờ đó, nhóm vẫn có thể bao gồm cả người dùng ứng dụng và những người không sử dụng ứng dụng.

#### 3. Quản lý thành viên

Trong quá trình sử dụng, nhóm có thể:

- Thêm thành viên mới.
- Hiển thị danh sách thành viên hiện tại.
- Hiển thị trạng thái đã liên kết hoặc chưa liên kết tài khoản.
- Xác định thành viên nào đang sử dụng ứng dụng để phục vụ gửi thông báo và lưu dữ liệu cá nhân.

#### 4. Thêm giao dịch thủ công

Người dùng có thể tạo giao dịch mới trong nhóm bằng cách nhập:

- Người thanh toán (chọn từ danh sách thành viên).
- Số tiền thanh toán.
- Nội dung giao dịch (tùy chọn).
- Thời gian giao dịch.

Sau khi xác nhận, giao dịch được lưu vào lịch sử giao dịch của nhóm.

#### 5. Thêm giao dịch từ hóa đơn

Người dùng có thể tải lên ảnh hóa đơn và chọn người thanh toán.

Hệ thống thực hiện:

1. Tải ảnh hóa đơn lên máy chủ.
2. Sử dụng chức năng OCR để nhận diện thông tin hóa đơn.
3. Trích xuất tổng tiền từ hóa đơn.
4. Tạo giao dịch mới trong nhóm.
5. Cho phép người dùng chỉnh sửa thông tin trước khi lưu nếu cần.

Sau khi xác nhận, giao dịch được thêm vào lịch sử giao dịch của nhóm.

#### 6. Xem lịch sử giao dịch

Mỗi nhóm đều có khu vực lịch sử giao dịch cho phép người dùng theo dõi toàn bộ hoạt động đã phát sinh.

Thông tin hiển thị bao gồm:

- Nội dung giao dịch.
- Người thanh toán.
- Số tiền.
- Thời gian tạo.
- Hóa đơn đính kèm (nếu có).
- Người tạo giao dịch.

Lịch sử giao dịch được cập nhật theo thời gian thực cho toàn bộ thành viên trong nhóm.

#### 7. Thực hiện chia bill

Khi người dùng nhấn nút **Chia Bill**, hệ thống thực hiện:

1. Tổng hợp toàn bộ giao dịch hiện có trong nhóm.
2. Tính tổng số tiền đã chi.
3. Chia đều tổng chi phí cho tất cả thành viên trong nhóm.
4. Tính số tiền thực tế mỗi thành viên đã thanh toán.
5. So sánh số tiền đã thanh toán với phần chi phí mà mỗi người phải chịu.
6. Xác định:
   - Thành viên đang nợ tiền.
   - Thành viên cần được hoàn tiền.
7. Tạo danh sách các khoản thanh toán cần thực hiện để cân bằng chi phí giữa các thành viên.

Ví dụ:

| Thành viên | Đã thanh toán |
|------------|--------------:|
| A | 600.000 |
| B | 300.000 |
| C | 100.000 |

Tổng chi phí là 1.000.000 VNĐ.

Mỗi thành viên phải chịu:

1.000.000 / 3 = 333.333 VNĐ

Kết quả:

- A được nhận lại 266.667 VNĐ.
- B cần thanh toán thêm 33.333 VNĐ.
- C cần thanh toán thêm 233.334 VNĐ.

Hệ thống hiển thị:

- B cần chuyển cho A: 33.333 VNĐ.
- C cần chuyển cho A: 233.334 VNĐ.

#### 8. Xác nhận thanh toán công nợ

Sau khi có kết quả chia bill:

- Các thành viên liên kết với tài khoản sẽ nhận được thông báo.
- Thành viên cần thanh toán có thể nhấn nút **Đã thanh toán** sau khi hoàn tất việc chuyển tiền.
- Hệ thống cập nhật trạng thái công nợ tương ứng.
- Các thành viên còn lại trong nhóm có thể theo dõi trạng thái thanh toán theo thời gian thực.

Chức năng này chỉ dùng để theo dõi công nợ giữa các thành viên và không tạo giao dịch chi tiêu mới trong ví cá nhân.

#### 9. Lưu kết quả chia bill vào ví cá nhân

Sau khi chia bill hoàn tất, mỗi thành viên đã liên kết với tài khoản ứng dụng có thể lựa chọn lưu phần chi phí thực tế của mình vào ví cá nhân.

Khi người dùng chọn **Lưu vào ví**:

- Hệ thống hiển thị danh sách các ví mà người dùng sở hữu hoặc tham gia.
- Người dùng chọn ví đích để lưu giao dịch.
- Hệ thống tạo một giao dịch chi tiêu mới tương ứng với phần chi phí thực tế mà người dùng phải chịu sau khi chia bill.

Ví dụ:

| Thành viên | Đã thanh toán | Chi phí thực tế |
|------------|--------------:|----------------:|
| A | 600.000 | 333.333 |
| B | 300.000 | 333.333 |
| C | 100.000 | 333.334 |

Nếu cả ba người đều chọn lưu vào ví:

- Ví của A ghi nhận giao dịch chi tiêu 333.333 VNĐ.
- Ví của B ghi nhận giao dịch chi tiêu 333.333 VNĐ.
- Ví của C ghi nhận giao dịch chi tiêu 333.334 VNĐ.

Hệ thống không lưu:

- Khoản tiền mà A đã ứng trước cho nhóm.
- Các khoản chuyển tiền giữa các thành viên để thanh toán công nợ.
- Các giao dịch trung gian phát sinh trong quá trình chia bill.

Nhờ đó, báo cáo tài chính cá nhân chỉ phản ánh phần chi phí thực tế mà người dùng đã tiêu dùng, tránh ghi nhận trùng lặp hoặc làm sai lệch thống kê chi tiêu.