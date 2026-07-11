1. tìm các bộ lọc ví ở 4 báo cáo (report screen) để chỉnh sửa thành bộ lọc ví cá nhân do ví nhóm không có ddữ liệu ở đây 
2. chi tiêu muc lũy kế 
- bộ lọc theo tuần, theo tháng không hoạt động
- lỗi overflowed ở ghi chú đường lý tưởng
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 15 pixels on the right.

The relevant error-causing widget was:
  Row
  Row:file:///D:/Luan-Van/Project/app/frontend/mobile/lib/screens/report/cumulative_budget_re
  port_screen.dart:480:11

To inspect this widget in Flutter DevTools, visit:
http://127.0.0.1:63119/HDBulYBn31s=/devtools//#/inspector?uri=http%3A%2F%2F127.0.0.1%3A63119%
2FHDBulYBn31s%3D%2F&inspectorRef=inspector-0

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow
and
black striped pattern. This is usually caused by the contents being too big for the
RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the 
RenderFlex to fit within the available space instead of being sized to their natural size.   
This is considered an error condition because it indicates that there is content that cannot 
be
seen. If the content is legitimately bigger than the available space, consider clipping it   
with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a 
Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#06da2 relayoutBoundary=up17 OVERFLOWING:  
  creator: Row ← Column ← Padding ← DecoratedBox ← Container ← Column ← Padding ←
  _SingleChildViewport
    ← IgnorePointer-[GlobalKey#21012] ← Semantics ← Listener ← _GestureSemantics ← ⋯
  parentData: offset=Offset(0.0, 296.0); flex=null; fit=null (can use size)
  constraints: BoxConstraints(0.0<=w<=296.0, 0.0<=h<=Infinity)
  size: Size(296.0, 17.0)
  direction: horizontal
  mainAxisAlignment: center
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢
◤◢◤◢◤◢◤
═════════════════════════════════════════════════════════════════════════════════════════════
═══════
- các số tiền ở biểu đồ không được đánh dấu phẩy
3. ở báo cáo sao vẫn thấy thiếu, nếu người dùng muốn coi báo cáo của tháng ttrước thì sao?
4. khi vào màn hình các trang con (như xuất dữ liệu chi tiêu, 4 báo cáo, 3 công cụ, chi tiết, recap, chi tiết theo mục) thì menu bottom nav bị lỗi, không chuyển được sang các màn hình khác
5. tìm các biểu đồ, và tạo tương tác với chúng,ví dụ khi click vào các thành phần của biểu đồ thì hiển thị thông tin chi tiết ( giống trong báo cáo thu nhập). hãt dựa vào biểu đồ mà đưa ra tương tác phù hơp

6. header của screen công cụ và setting đang là bản cũ, hãy chỉnh theo bản mới như Report
7. khi xuất file xong thì có nút xem csv, để cho người dùng mở ra xem