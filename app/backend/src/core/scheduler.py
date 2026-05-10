from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.core.websocket_manager import manager
# Giả định Khang có file cấu hình Database ở app.database.session hoặc tương đương
# from app.db.session import SessionLocal 
from app.models.index import Debt, User

scheduler = AsyncIOScheduler()

async def remind_unpaid_debts():
    # db = SessionLocal()
    # Chú ý: Cần import SessionLocal đúng đường dẫn của dự án
    db = None # TODO: Gán SessionLocal()
    try:
        # Nếu chưa kết nối DB, tạm bỏ qua query
        if not db: return

        # 1. Tìm các khoản nợ chưa trả (unpaid)
        unpaid_debts = db.query(Debt).filter(Debt.status == "unpaid").all()
        
        for debt in unpaid_debts:
            # 2. Tạo nội dung nhắc nợ "tổng sỉ vả" buổi sáng
            # Cần đảm bảo có relationship creditor = relationship("User") trong bảng Debt
            # Hoặc truy vấn bảng User trực tiếp
            creditor_username = "Chủ nợ" # debt.creditor.username nếu có relationship
            
            payload = {
                "event_type": "MORNING_ROAST",
                "message": f"Dậy chưa con nợ? Nhắc nhẹ khoản {debt.amount}k cho {creditor_username} nha!",
                "mascot_mood": "annoyed"
            }
            # 3. Bắn real-time nếu con nợ đang online
            await manager.send_personal_message(payload, debt.debtor_id)
    finally:
        if db:
            db.close()

# Đặt lịch chạy mỗi ngày lúc 9:00 sáng
scheduler.add_job(remind_unpaid_debts, 'cron', hour=9, minute=0)
