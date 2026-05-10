from fastapi import WebSocket
from typing import Dict
from uuid import UUID

class ConnectionManager:
    def __init__(self):
        # Lưu trữ dưới dạng {user_id: websocket_connection}
        self.active_connections: Dict[UUID, WebSocket] = {}

    async def connect(self, user_id: UUID, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: UUID):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_personal_message(self, message: dict, user_id: UUID):
        """Gửi tin nhắn riêng biệt cho đúng con nợ"""
        if user_id in self.active_connections:
            await self.active_connections[user_id].send_json(message)

manager = ConnectionManager()