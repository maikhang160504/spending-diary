# Fix & Cải Thiện App SpendDiary — Kế Hoạch Triển Khai

Dựa trên [fix_app.json](file:///d:/Luan-Van/Project/fix_app.json), thực hiện sửa lỗi, cải thiện UI/UX và bổ sung tính năng cho ứng dụng Flutter SpendDiary.

## User Review Required

> [!IMPORTANT]
> Đây là một task rất lớn, gồm ~15 thay đổi trải rộng trên ~12 file. Tôi đề xuất chia thành **3 phase** để dễ kiểm soát và test:
> - **Phase 1**: Sửa lỗi logic (bill-detail, detail-story, chat-screen, LLM-response)
> - **Phase 2**: Cải thiện UI chính (home header, story cards, camera, segment tabs)
> - **Phase 3**: Tính năng mới (loading animation, streak animation, settings avatar/AI style swap)

> [!WARNING]
> Cần thêm package `lottie` vào `pubspec.yaml` để dùng animation Loading.json / Fire.json. Cần thêm `image_picker` (đã có) cho đổi avatar.

## Open Questions

> [!IMPORTANT]
> 1. **Kích thước ảnh tối ưu cho story**: Tôi đề xuất dùng aspect ratio **4:3** (chiều rộng full, cao ~250px) thay vì hardcode 220px hiện tại — bạn đồng ý không?
> 2. **Khung quét bill**: Hiện tại là 280×180 (ngang). Bạn muốn đổi sang chiều dọc, tôi đề xuất **280×400** (dọc, phù hợp với hóa đơn VN) — OK không?
> 3. **Camera capture resolution**: Hiện dùng `ResolutionPreset.high`. Có muốn đổi sang `ResolutionPreset.max` để ảnh rõ hơn cho OCR?

---

## Proposed Changes

### Phase 1: Sửa Lỗi Logic

---

#### 1. Bill Detail — Không xem chi tiết được
**Vấn đề**: Story tạo bằng bill không xem chi tiết được vì `storyId` có thể null hoặc rỗng khi transaction đến từ bill.

#### [MODIFY] [detail_story_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/story/detail_story_screen.dart)
- Khi `storyId` rỗng nhưng có `transactionId`, fallback load trực tiếp transaction data thay vì chỉ gọi `getStory()`
- Thêm fallback: nếu `getStory()` fail (404), thử load qua `getTransactions()` với id

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Đảm bảo `_TransactionStoryCard` luôn có navigable ID (dùng `tx['id']` khi không có `storyId`)

---

#### 2. Detail Story — Không lướt sang story khác + Không cho chỉnh sửa/xóa

#### [MODIFY] [detail_story_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/story/detail_story_screen.dart)
- Nhận thêm `List<String> allStoryIds` + `int initialIndex` qua route params
- Bọc nội dung trong `PageView` để lướt qua các story khác
- Thêm nút **Xóa** (với confirm dialog) gọi `deleteTransaction()`
- Cải thiện nút **Chỉnh sửa** → mở bottom sheet giống camera_confirm_screen cho phép edit amount/category/note

#### [MODIFY] [app_routes.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/routes/app_routes.dart)
- Cập nhật route `storyDetail` để hỗ trợ extra params (allStoryIds, initialIndex)

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Khi navigate tới detail, truyền thêm danh sách transaction IDs và vị trí hiện tại

---

#### 3. Chat Screen — Ô xác nhận dư thông tin + Không cho chỉnh sửa category

#### [MODIFY] [chat_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/chat/chat_screen.dart)
- **Ô xác nhận (transaction preview card)**: Loại bỏ phần text lặp lại, chỉ hiển thị card giao dịch gọn (category + amount + note)
- **Cho phép chỉnh sửa category**: Thêm nút "Chỉnh sửa" bên cạnh nút "Lưu giao dịch" → mở bottom sheet giống camera_confirm_screen với dropdown category

---

#### 4. LLM Response — Câu phản hồi quá dài

#### [MODIFY] [prompt.py](file:///d:/Luan-Van/Project/expense-ocr-nlu/src/nlg/prompt.py)
- Thêm instruction giới hạn: **"Trả lời tối đa 30 từ. Ngắn gọn, dễ hiểu, đúng vai."** vào `_LIST_EMOTION_INSTRUCTION`

#### [MODIFY] [chat_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/chat/chat_screen.dart)
- Thêm client-side truncation: nếu LLM story > 120 ký tự, cắt + thêm "..."

---

### Phase 2: Cải Thiện UI

---

#### 5. Home Header — Ẩn khi cuộn xuống, hiện khi cuộn lên

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Chuyển từ `SliverToBoxAdapter` cho header sang `SliverAppBar` hoặc custom `SliverPersistentHeader` với:
  - **Expanded**: hiển thị đầy đủ (date, greeting, streak, wallets, balance card)
  - **Collapsed**: chỉ hiển thị "Chào [tên]!" + segment tabs (Story/Gallery/Calendar)
- Segment tabs luôn sticky khi scroll

#### 6. Segment Tabs — Đẹp hơn

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Redesign segment tabs với animated indicator (slide animation khi chuyển tab)
- Dùng gradient background subtle cho tab đang chọn
- Icon lớn hơn, typography rõ ràng hơn

#### 7. Story Cards — Giảm khoảng cách với cạnh màn hình

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Giảm `margin: EdgeInsets.symmetric(horizontal: 16)` xuống `horizontal: 10`
- Tối ưu padding nội dung card

#### 8. Ảnh Story — Kích thước tối ưu

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Ảnh story dùng `aspectRatio: 4/3` thay vì fixed height 220
- Dùng `BoxFit.cover` + `ClipRRect` với borderRadius

#### [MODIFY] [camera_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_screen.dart)
- Điều chỉnh camera resolution để ra ảnh phù hợp aspect ratio 4:3

#### 9. Nút chụp Camera — Viền màu bạc hà

#### [MODIFY] [camera_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_screen.dart)
- Đổi border của nút chụp từ `Colors.white` sang `AppColors.teal` (mint/bạc hà)
- Thêm subtle glow effect

#### 10. Khung quét bill — Lớn hơn theo chiều dọc

#### [MODIFY] [camera_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/camera/camera_screen.dart)
- Đổi khung từ 280×180 (ngang) sang **280×400** (dọc) phù hợp hóa đơn Việt Nam
- Cập nhật corner brackets positions tương ứng

---

### Phase 3: Animation & Settings

---

#### 11. Loading Animation — Dùng Lottie Loading.json

#### [MODIFY] [pubspec.yaml](file:///d:/Luan-Van/Project/app/frontend/mobile/pubspec.yaml)
- Thêm dependency `lottie: ^3.1.3`
- Thêm assets `- assets/animations/`

#### [MODIFY] [skeleton.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/widgets/skeleton.dart)
- Thay shimmer skeleton bằng Lottie animation từ `Loading.json` khi loading data

#### [MODIFY] [home_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/home/home_screen.dart)
- Dùng Lottie loading thay cho skeleton cards

---

#### 12. Streak Animation — Hiệu ứng giữ chuỗi thành công

#### [MODIFY] [streak_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/streak/streak_screen.dart)
- Khi `currentStreak >= previousStreak` (streak thành công), hiển thị Fire.json Lottie animation
- Animation chạy 1 lần khi mở màn hình streak, phía sau emoji 🔥

---

#### 13. Settings — Đổi avatar + Hiệu ứng đổi phong cách AI

#### [MODIFY] [settings_screen.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/settings/settings_screen.dart)
- **Đổi avatar**: Tap vào avatar circle → mở image picker → upload qua `uploadFile()` → update profile
- **Hiệu ứng đổi phong cách AI**: 
  - Khi chọn phong cách mới, 2 icon AI (Cool + Angry) animate swap chỗ cho nhau với `AnimatedPositioned`
  - Animation chạy ~1s rồi dừng lại ở vị trí đã chọn
- **Chỉnh sửa thông tin cá nhân**: Đổi dialog read-only thành editable dialog với TextFields cho username, age_group, job_type → gọi `updateProfile()` / `updateSettings()`

#### [MODIFY] [api_client.dart](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/services/api_client.dart)
- Thêm method `uploadAvatar()` nếu cần endpoint riêng, hoặc dùng `uploadFile()` + `updateProfile()`

---

### Cải thiện UI chung (toàn bộ các màn hình)

Áp dụng các nguyên tắc chung cho tất cả các screen:
- Dùng `AppColors.teal` gradient cho header consistently
- Thêm subtle micro-animations (fade in, scale) cho các card/item khi xuất hiện
- Bo tròn corners đồng nhất (`AppRadii.lg` = 16)
- Shadow nhẹ nhàng hơn, tạo depth
- Typography rõ ràng, hierarchy tốt

Các screen cụ thể sẽ được cải thiện nhẹ:
- **Chat**: bubble colors, typing animation mượt hơn
- **Camera**: dark theme nhất quán, glow effects
- **Gallery**: grid spacing, image quality
- **Calendar**: giữ nguyên chế độ xem, polish colors
- **Profile/Settings**: clean layout
- **Splash/Loading**: Lottie animation

---

## Verification Plan

### Automated Tests
- `flutter analyze` — đảm bảo không có warning/error mới
- `flutter build apk --debug` — build thành công

### Manual Verification
- Hot reload app đang chạy và kiểm tra từng screen:
  1. Chat: gửi tin nhắn, xem ô xác nhận không lặp text, có thể chỉnh category
  2. Home: scroll xuống header thu gọn, scroll lên header hiện lại
  3. Story cards: khoảng cách cạnh đã giảm, ảnh đúng kích thước
  4. Detail story: lướt sang story khác, xóa/chỉnh sửa story hoạt động
  5. Camera: nút chụp viền bạc hà, khung bill dọc lớn hơn
  6. Streak: animation fire khi có streak
  7. Settings: đổi avatar, hiệu ứng swap AI style
  8. Bill story: tap vào → xem chi tiết được
