"""Smoke tests for the AI service. Run with: pytest tests -q"""
from __future__ import annotations

import io

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="module")
def client() -> TestClient:
    return TestClient(app)


def test_health(client: TestClient) -> None:
    r = client.get("/health")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["status"] == "ok"
    assert "version" in data


def test_nlu_record_text(client: TestClient) -> None:
    r = client.post("/api/v1/nlu/infer", json={"text": "ăn phở 45k"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["intent"] in ("Record", "Action", "Chitchat")
    assert body["text"] == "ăn phở 45k"
    assert body["backend"] in ("real", "mock")
    assert body["amount"] in (None, 45000.0, 45000)


def test_nlu_validation(client: TestClient) -> None:
    r = client.post("/api/v1/nlu/infer", json={"text": ""})
    assert r.status_code == 422


def test_expense_from_text(client: TestClient) -> None:
    r = client.post(
        "/api/v1/expense/from-text",
        json={"text": "trà sữa 35k", "user_id": "u1"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["flow"] == "text"
    assert body["extracted"]["amount"] in (None, 35000.0, 35000)


def test_ocr_text(client: TestClient) -> None:
    r = client.post(
        "/api/v1/ocr/text",
        json={"text": "TONG TIEN 150.000 cafe"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["suggestion"]["amount"] in (None, 150000)


def test_ocr_image_mock(client: TestClient) -> None:
    fake_jpg = io.BytesIO(b"\xff\xd8\xff\xe0FAKE")
    r = client.post(
        "/api/v1/ocr/image",
        files={"file": ("bill.jpg", fake_jpg, "image/jpeg")},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["backend"] in ("mock", "real")
    assert body["requires_confirmation"] is True
