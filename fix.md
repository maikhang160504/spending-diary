1. không chỉnh sửa được giao dịch định kì
2.
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 117 pixels on the right.

The relevant error-causing widget was:
  Row
  Row:file:///D:/Luan-Van/Project/app/frontend/mobile/lib/screens/settings/export_data_screen.dart:201:26 

To inspect this widget in Flutter DevTools, visit:
http://127.0.0.1:64898/741CbCmILqU=/devtools//#/inspector?uri=http%3A%2F%2F127.0.0.1%3A64898%2F741CbCmILqU
%3D%2F&inspectorRef=inspector-0

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,        
like a ListView.
The specific RenderFlex in question is: RenderFlex#18df5 relayoutBoundary=up10 OVERFLOWING:
  creator: Row ← Semantics ← DefaultTextStyle ← Padding ← Column ← IntrinsicWidth ← Semantics ←
    DefaultTextStyle ← AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#97433 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← CustomPaint ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=232.0, 0.0<=h<=Infinity)
  size: Size(232.0, 33.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤      
════════════════════════════════════════════════════════════════════════════════════════════════════ xuất rồi không thấy file