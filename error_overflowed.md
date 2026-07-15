1. The Flutter DevTools debugger and profiler on Edge is available at:
http://127.0.0.1:63742/eTM_Urm7jDk=/devtools/?uri=ws://127.0.0.1:63742/eTM_Urm7jDk=/ws
Starting application from main method in: org-dartlang-app:/web_entrypoint.dart.
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 63 pixels on the right.

The relevant error-causing widget was:
  Row Row:file:///D:/Luan-Van/Project/app/frontend/mobile/lib/screens/auth/login_screen.dart:377:33

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#0b9bc relayoutBoundary=up44 OVERFLOWING:
  creator: Row ← Align ← Padding ← Listener ← RawGestureDetector ← GestureDetector ← Semantics ←
    DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=104.0, 0.0<=h<=Infinity)
  size: Size(104.0, 26.0)
  direction: horizontal
  mainAxisAlignment: center
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
Another exception was thrown: A RenderFlex overflowed by 87 pixels on the right.
2. 