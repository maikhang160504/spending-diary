from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.core.websocket_manager import manager
from uuid import UUID

router = APIRouter()

@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: UUID):
    await manager.connect(user_id, websocket)
    try:
        while True:
            # Giữ kết nối mở, có thể nhận heartbeat hoặc message từ Mobile ở đây
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id)