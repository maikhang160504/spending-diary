"""Integration tests for the asynchronous 5-stage processing pipeline."""
from __future__ import annotations

import io
import pytest
import httpx
import anyio

from app.main import app
from app.services import asynchronous_pipeline


@pytest.mark.anyio
async def test_async_pipeline_e2e() -> None:
    # Explicitly start the pipeline workers within the test's event loop
    asynchronous_pipeline.start_pipeline()
    
    try:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            
            # 1. Submit a fake receipt image to the pipeline
            fake_jpg = io.BytesIO(b"\xff\xd8\xff\xe0FAKE_RECEIPT_BYTES")
            response = await client.post(
                "/api/v1/pipeline/process",
                files={"file": ("bill.jpg", fake_jpg, "image/jpeg")},
            )
            assert response.status_code == 200, response.text
            data = response.json()
            assert "job_id" in data
            assert data["status"] == "pending"
            
            job_id = data["job_id"]
            
            # 2. Poll the job status using anyio.sleep to let background tasks run
            max_polls = 100
            completed = False
            for _ in range(max_polls):
                status_response = await client.get(f"/api/v1/pipeline/jobs/{job_id}")
                assert status_response.status_code == 200, status_response.text
                job_data = status_response.json()
                
                if job_data["status"] == "completed":
                    completed = True
                    assert job_data["progress"] == 100
                    assert job_data["result"] is not None
                    assert "extracted" in job_data["result"]
                    break
                elif job_data["status"] == "failed":
                    raise AssertionError(f"Job failed unexpectedly: {job_data['error']}")
                    
                await anyio.sleep(0.05)
                
            assert completed, f"Job {job_id} did not finish in time"
            
            # 3. Check listing all jobs
            list_response = await client.get("/api/v1/pipeline/jobs")
            assert list_response.status_code == 200
            all_jobs = list_response.json()
            assert job_id in all_jobs
            assert all_jobs[job_id]["status"] == "completed"
            
    finally:
        # Stop the pipeline workers to clean up tasks
        asynchronous_pipeline.stop_pipeline()
