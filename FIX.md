1. Home
- header : Gia đình hay nhóm bạn là ví chung, và nó dẫn đến shared wallet
- chế độ xem : 
    + View Gallery :thêm ngày tháng vào ảnh (28-03), giao dịch có thể "+" hoặc "-", nếu "-" thì ghi là "-" trước số tiền (đã làm)
    + View Calendar : hiển thị giao dịch dưới dạng lịch, mỗi ngày chứa ảnh vuông giao dịch theo dạng stacked, nghiêng ảnh dần,có + nếu ảnh nhiều , có thể xem chi tiết giao dịch khi tap vào ảnh, nếu chọn ngày thì hiển thị các giao dịch trong ngày đó ở bên dưới dạng gallery, ngày tháng đúng với lịch hiện tại,.., mockdata để hiển thị 
    + View Detail : Không trượt trái or phải để xem chi tiết giao dịch tiếp theo, đang lỗi dấu tiếng việt
- ví Chung : tương tự ví rriêng tức home (có 3 view story/gallery/calendar), 
    + phần header : xem thành viên ,có nút + để thêm thành viên,  
    + có 3 view 
        + view story : cá nhân và người khác, nếu cá nhân có vương miện là chủ của story
        + view gallery
        + view calendar 
- Đổi lại icon của Chat trong tab Home (giống messendger)

2. Camera
khi mở nhảy thẳng vào màn hình camera_screen.dart 
- trên cùng có 2 chế độ : Ảnh (mặc định) và Bill
    +  camera hiển thị trực tiếp trong app mà không mở app camera, có các nút chụp, thêm ảnh, Xoay camera, màn hình preview ảnh vừa chụp
    +  có thể zoom và focus
    +   nếu là bill thì có khung camera ở giữa để người dùng dễ dàng chụp bill 
- hoàn thiện luồng hoạt động

3. mascot nhân vật MiMo
- có viền background : assets/MiMo/background/background.png
- Vị trí hiển thị ở: ngay gốc phải dưới trên nav, (ảnh trạng thái-> background-> popup)
- Thời gian xuất hiện : sau khi người dùng nhập chi tiêu thành công
- thời gian ẩn : sau 5s
- hiệu ứng : ảnh + bong bóng text chứa câu trả lời (quay về bên trái), có thể co dãn tùy vào độ dài của câu trả lời 



    

