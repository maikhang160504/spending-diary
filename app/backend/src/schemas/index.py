from pydantic import BaseModel, EmailStr, Field
from uuid import UUID
from datetime import datetime
from typing import Optional, List
from decimal import Decimal

# --- USER SCHEMAS ---
class UserBase(BaseModel):
    username: str
    email: EmailStr
    avatar_url: Optional[str] = None
    preferred_vibe: str = "funny"

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True # Cho phép Pydantic đọc dữ liệu từ SQLAlchemy Model

# --- TRANSACTION SCHEMAS ---
class TransactionBase(BaseModel):
    id: UUID # Mobile-generated UUID
    wallet_id: UUID
    amount: Decimal = Field(..., max_digits=15, decimal_places=2)
    category: str
    note: Optional[str] = None
    created_at: datetime # Thời gian chi tiêu thực tế

class TransactionCreate(TransactionBase):
    """Dữ liệu nhận vào từ Mobile khi Sync"""
    pass

class TransactionUpdate(BaseModel):
    """Dùng khi người dùng sửa Note hoặc Category"""
    category: Optional[str] = None
    note: Optional[str] = None

class TransactionResponse(TransactionBase):
    """Dữ liệu trả về cho Story Feed (kèm AI comment)"""
    creator_id: UUID
    ai_comment: Optional[str] = None
    mascot_mood: Optional[str] = None
    server_synced_at: datetime

    class Config:
        from_attributes = True

# --- WALLET SCHEMAS ---
class WalletBase(BaseModel):
    name: str
    type: str # 'personal' hoặc 'group'

class WalletCreate(WalletBase):
    pass

class WalletResponse(WalletBase):
    id: UUID
    owner_id: UUID
    members: List[UserResponse] = []

    class Config:
        from_attributes = True

# --- AI ANALYSIS SCHEMA ---
class AIAnalysisRequest(BaseModel):
    text: str # Ví dụ: "ăn phở 50k"

class AIAnalysisResponse(BaseModel):
    amount: Decimal
    category: str
    ai_comment: str
    mascot_mood: str

# --- SPLIT BILL SCHEMAS ---
class SplitMember(BaseModel):
    user_id: UUID
    # Giá trị này có thể là: 0 (nếu chia đều), số tiền cụ thể, hoặc tỷ lệ %
    value: Optional[Decimal] = Decimal("0")

class SplitBillRequest(BaseModel):
    wallet_id: UUID
    payer_id: UUID # Người đã trả tiền trước
    total_amount: Decimal = Field(..., max_digits=15, decimal_places=2)
    category: str
    note: str
    split_type: str # 'equal', 'exact', 'percentage'
    members: List[SplitMember] # Danh sách những người cùng chia (bao gồm cả payer)

