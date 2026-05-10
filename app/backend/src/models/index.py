from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey, Boolean, Text, Table
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship, DeclarativeBase
from sqlalchemy.sql import func
import uuid

class Base(DeclarativeBase):
    pass

# Bảng phụ để thể hiện mối quan hệ N-N giữa User và Wallet
wallet_members = Table(
    "wallet_members",
    Base.metadata,
    Column("wallet_id", UUID(as_uuid=True), ForeignKey("wallets.id", ondelete="CASCADE"), primary_key=True),
    Column("user_id", UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("role", String(20), server_default="member"),
    Column("joined_at", DateTime(timezone=True), server_default=func.now()),
)

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    hashed_password = Column(Text, nullable=False)
    avatar_url = Column(Text, nullable=True)
    preferred_vibe = Column(String(20), server_default="funny")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Quan hệ
    owned_wallets = relationship("Wallet", back_populates="owner")
    wallets = relationship("Wallet", secondary=wallet_members, back_populates="members")
    transactions = relationship("Transaction", back_populates="creator")

class Wallet(Base):
    __tablename__ = "wallets"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    type = Column(String(20)) # 'personal' hoặc 'group'
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Quan hệ
    owner = relationship("User", back_populates="owned_wallets")
    members = relationship("User", secondary=wallet_members, back_populates="wallets")
    transactions = relationship("Transaction", back_populates="wallet")

class Transaction(Base):
    __tablename__ = "transactions"

    # Lưu ý: id không có default=uuid.uuid4 vì Mobile sẽ gửi ID lên
    id = Column(UUID(as_uuid=True), primary_key=True) 
    wallet_id = Column(UUID(as_uuid=True), ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False, index=True)
    creator_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    category = Column(String(50), nullable=False)
    note = Column(Text, nullable=True)
    ai_comment = Column(Text, nullable=True)
    mascot_mood = Column(String(30), nullable=True)
    is_deleted = Column(Boolean, default=False)
    
    # Thời gian tiêu tiền thực tế (từ Mobile)
    created_at = Column(DateTime(timezone=True), nullable=False, index=True)
    # Thời gian đồng bộ lên hệ thống
    server_synced_at = Column(DateTime(timezone=True), server_default=func.now())

    # Quan hệ
    wallet = relationship("Wallet", back_populates="transactions")
    creator = relationship("User", back_populates="transactions")

class Debt(Base):
    __tablename__ = "debts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    wallet_id = Column(UUID(as_uuid=True), ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False)
    debtor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    creditor_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    status = Column(String(20), default="unpaid")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

