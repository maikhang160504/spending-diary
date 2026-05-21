"""Pydantic schemas for the NLU endpoint."""
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


Intent = Literal["Record", "Action", "Chitchat", "Unknown"]
RecordType = Literal["Expense", "Income"]


class NLUProfile(BaseModel):
    """User context attached to a request (budget, preference, ...)."""

    model_config = ConfigDict(extra="allow")

    user_id: str | None = None
    budget_total: float | None = Field(default=None, ge=0)
    budget_remain: float | None = Field(default=None, ge=0)
    preferred_vibe: str | None = None


class NLURequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=1000, examples=["ăn phở 45k"])
    profile: NLUProfile | None = None
    run_llm: bool = False
    emotion: str | None = Field(default=None, examples=["hai_huoc"])
    user_id: str | None = None


class MultiRecordItem(BaseModel):
    text: str
    amount: float | None = None
    category: str | None = None
    record_type: RecordType | None = None


class ActionDetails(BaseModel):
    model_config = ConfigDict(extra="allow")

    verb: str | None = None
    target: str | None = None
    target_type: str | None = None
    value: float | None = None
    unit: str | None = None


class NLUResponse(BaseModel):
    """Normalized NLU output consumed by the backend."""

    model_config = ConfigDict(extra="allow")

    intent: Intent
    intent_confidence: float | None = None
    text: str
    item: str | None = None
    category: str | None = None
    amount: float | None = None
    record_type: RecordType | None = None
    is_expense: bool | None = None
    income_type: str | None = None
    action_type: str | None = None
    action_details: ActionDetails | None = None
    multi_records: list[MultiRecordItem] = []
    multi_record_task: bool = False
    sentiment: str | None = None
    nlg_prompt: dict[str, Any] | None = None
    gemini_json: dict[str, Any] | None = None
    backend: str = Field(default="mock", description="`real` if full pipeline used, else `mock`.")
    latency_ms: int | None = None
