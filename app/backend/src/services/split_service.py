from app.schemas.index import SplitBillRequest
from sqlalchemy.orm import Session
from app.models.index import Debt, Transaction
import uuid
from datetime import datetime
from decimal import Decimal

def calculate_split(request: SplitBillRequest):
    results = []
    num_members = len(request.members)
    if num_members == 0:
        return results
        
    if request.split_type == 'equal':
        share_amount = request.total_amount / num_members
        for m in request.members:
            if m.user_id != request.payer_id:
                results.append({"debtor_id": m.user_id, "amount": share_amount})

    elif request.split_type == 'percentage':
        for m in request.members:
            if m.user_id != request.payer_id:
                # value chứa % (VD: 30 cho 30%)
                share_amount = (m.value / Decimal("100")) * request.total_amount
                results.append({"debtor_id": m.user_id, "amount": share_amount})

    elif request.split_type == 'exact':
        for m in request.members:
            if m.user_id != request.payer_id:
                # value chứa số tiền chính xác
                results.append({"debtor_id": m.user_id, "amount": m.value})

    return results

from app.core.websocket_manager import manager

async def notify_debtors_via_websocket(debt_list, payer_id: uuid.UUID):
    for debt in debt_list:
        payload = {
            "event_type": "DEBT_REMINDER",
            "creditor_id": str(payer_id),
            "amount": float(debt['amount']),
            "message": "Ê! Tiền lẩu hôm nay tới công chuyện rồi, đóng lẹ không Mascot nó cắn kìa!",
            "mascot_mood": "annoyed"
        }
        await manager.send_personal_message(payload, debt['debtor_id'])

async def split_bill_service(db: Session, request: SplitBillRequest):
    # 1. Tính toán nợ
    debt_list = calculate_split(request)
    
    # 2. Tạo bản ghi Debt trong DB
    for debt in debt_list:
        new_debt = Debt(
            wallet_id=request.wallet_id,
            debtor_id=debt['debtor_id'],
            creditor_id=request.payer_id,
            amount=debt['amount'],
            status='unpaid'
        )
        db.add(new_debt)
        
    # (Lưu ý: Bạn cũng có thể add thêm Transaction ở đây nếu muốn hiển thị bill tổng)
    
    # 3. Kích hoạt Mascot "nhắc nhẹ" những người nợ qua WebSocket
    await notify_debtors_via_websocket(debt_list, request.payer_id)
    
    db.commit()
    return {"message": "Chia tiền thành công và đã ghi nhận công nợ!"}