# Phân Tích Logic: Rời Ví Chung & Xóa Mục Tiêu Nhóm

---

## 1. Rời Ví Chung (Leave Shared Wallet)

### Hiện trạng

Frontend trong [share_wallet_screen.dart:L407-L411](file:///d:/Luan-Van/Project/app/frontend/mobile/lib/screens/wallet/share_wallet_screen.dart#L407-L411):
- Thành viên thường (`member`) thấy nút `exit_to_app` (Rời ví).
- Bấm vào → gọi `_confirmRemove(member)` → gọi API `DELETE /wallets/:id/members/:memberId`.

Backend trong [wallets.service.js:L188-L198](file:///d:/Luan-Van/Project/app/backend/src/modules/wallets/wallets.service.js#L188-L198):

```js
async function removeMember(userId, walletId, memberId) {
  await assertMember(walletId, userId, ['owner']); // ← CHỈ OWNER mới được gọi
  if (memberId === userId) {
    throw ApiError.badRequest('Owner cannot remove themselves...');
  }
  ...
}
```

### ❌ LỖ HỔNG #1 — Thành viên không thể tự rời ví

`removeMember` yêu cầu `userId` (người gọi) phải là **owner**. Nếu một `member` tự bấm nút rời ví, backend sẽ trả về **403 Forbidden**.

| Trường hợp | Gọi API | Kết quả |
|---|---|---|
| Owner xóa member khác | ✅ OK | Hoạt động đúng |
| Member tự rời ví | ❌ FAIL | 403 — `assertMember` yêu cầu owner |

### ❌ LỖ HỔNG #2 — Owner không thể rời ví mà không có người thay thế

`removeMember` ném lỗi nếu `memberId === userId` → Owner hoàn toàn **bị kẹt** trong ví, không thể rời đi cho dù muốn.

Không có endpoint `transfer ownership` nào tồn tại.

### ❌ LỖ HỔNG #3 — Dialog xác nhận sai context

`_confirmRemove` hiển thị nội dung `'Bạn có chắc muốn xoá [tên] khỏi ví không?'` cho cả khi **chính user tự rời ví**, sẽ gây nhầm lẫn UX.

---

## 2. Xóa Mục Tiêu Nhóm (Delete Group Goals/Challenges)

### Hiện trạng

Backend trong [goals.service.js:L217-L223](file:///d:/Luan-Van/Project/app/backend/src/modules/goals/goals.service.js#L217-L223):

```js
async function remove(userId, goalId) {
  const r = await query(
    `UPDATE goals SET status = 'cancelled' WHERE id = $1 AND user_id = $2`,
    [goalId, userId]
  );
  if (r.rowCount === 0) throw ApiError.notFound('Goal not found.');
}
```

### ❌ LỖ HỔNG #4 — Thành viên nhóm không thể rời mục tiêu

Endpoint `DELETE /goals/:id` chỉ cho phép `user_id = creator` xóa mục tiêu (soft-delete thành `cancelled`).

Một thành viên tham gia mục tiêu nhóm qua mã mời (`goal_members`) **không có cách nào rời mục tiêu** — không có endpoint `DELETE /goals/:id/members` (rời khỏi mục tiêu nhóm mà không hủy cả mục tiêu).

### ❌ LỖ HỔNG #5 — Owner xóa goal nhóm = xóa tất cả

Khi owner xóa mục tiêu nhóm, mục tiêu bị set `status = 'cancelled'` cho **tất cả thành viên** mà không có cảnh báo. Không có thông báo cho các thành viên khác.

### ❌ LỖ HỔNG #6 — Thành viên nhóm có thể contribute vào goal của người khác nhưng không biết mình là ai

`update` trong goals.service kiểm tra `WHERE user_id = $2` → thành viên thường **không thể chỉnh sửa** mục tiêu. Nhưng không có sự phân biệt rõ ràng vai trò nào trong `goal_members` có thể update goal.

---

## 3. Đề Xuất Sửa

### Backend

#### a. Thêm endpoint **tự rời ví** (Leave Wallet)
```js
// wallets.service.js — thêm hàm mới
async function leaveWallet(userId, walletId) {
  const role = await assertMember(walletId, userId); // bất kỳ role
  if (role === 'owner') {
    throw ApiError.badRequest('Chủ ví không thể tự rời. Hãy chuyển quyền sở hữu trước.');
  }
  await query(
    `DELETE FROM wallet_members WHERE wallet_id = $1 AND user_id = $2`,
    [walletId, userId]
  );
}
```

```js
// wallets.routes.js
router.post('/:id/leave', controller.leaveWallet);
```

#### b. Thêm endpoint **rời mục tiêu nhóm**
```js
// goals.service.js — thêm hàm mới
async function leaveGoal(userId, goalId) {
  const goal = await getById(userId, goalId);
  if (goal.user_id === userId) {
    throw ApiError.badRequest('Chủ mục tiêu không thể rời. Hãy xóa mục tiêu.');
  }
  await query(
    `DELETE FROM goal_members WHERE goal_id = $1 AND user_id = $2`,
    [goalId, userId]
  );
}
```

```js
// goals.routes.js
router.post('/:id/leave', controller.leaveGoal);
```

### Frontend

#### a. Sửa `_confirmRemove` trong `share_wallet_screen.dart`
- Tách 2 luồng: **Owner xóa member** vs **Member tự rời ví**
- Khi **member tự rời** → gọi `POST /wallets/:id/leave` (endpoint mới)
- Cập nhật nội dung dialog: `'Bạn có chắc muốn rời khỏi ví này không?'`
- Sau khi rời → navigate về trang chủ (`context.go('/')`)

#### b. Thêm nút "Rời mục tiêu" cho thành viên nhóm trong `goal_detail_screen.dart`
- Nếu user không phải owner nhưng là `goal_member` → hiển thị nút **"Rời mục tiêu"**
- Gọi `POST /goals/:id/leave`

---

## Tóm Tắt Lỗ Hổng

| # | Mức độ | Vấn đề |
|---|--------|---------|
| 1 | 🔴 Blocker | Member gọi rời ví → 403 Forbidden (backend từ chối) |
| 2 | 🔴 Blocker | Owner bị kẹt trong ví, không có cơ chế chuyển quyền |
| 3 | 🟡 UX | Dialog nhầm "xóa" thay vì "rời" khi user tự rời |
| 4 | 🔴 Blocker | Không có endpoint để thành viên rời mục tiêu nhóm |
| 5 | 🟠 Logic | Owner xóa mục tiêu nhóm mà không thông báo thành viên |
| 6 | 🟡 Minor | Chưa phân vai trò owner/member cho phép chỉnh sửa mục tiêu |
