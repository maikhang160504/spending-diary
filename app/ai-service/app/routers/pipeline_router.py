"""Router for asynchronous 5-stage pipeline endpoints."""
from __future__ import annotations

from typing import Any, Dict
from fastapi import APIRouter, File, UploadFile, HTTPException
from pydantic import BaseModel

from app.services import asynchronous_pipeline as pipeline

router = APIRouter(prefix="/pipeline", tags=["pipeline"])

MAX_BYTES = 8 * 1024 * 1024  # 8 MB


class JobSubmitResponse(BaseModel):
    job_id: str
    status: str


class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    current_stage: str
    progress: int
    created_at: str
    updated_at: str
    result: Any | None = None
    error: str | None = None


@router.post(
    "/process",
    response_model=JobSubmitResponse,
    summary="Submit receipt image to asynchronous pipeline",
)
async def submit_image(
    file: UploadFile = File(..., description="Receipt image (jpg/png)"),
) -> JobSubmitResponse:
    raw = await file.read()
    if len(raw) > MAX_BYTES:
        raise HTTPException(status_code=400, detail="Image is larger than 8 MB.")
        
    job_id = pipeline.submit_job(raw, file.filename)
    return JobSubmitResponse(job_id=job_id, status="pending")


@router.get(
    "/jobs/{job_id}",
    response_model=JobStatusResponse,
    summary="Get pipeline job status and result",
)
def get_job_status(job_id: str) -> JobStatusResponse:
    job = pipeline.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found.")
    return JobStatusResponse(**job)


@router.get(
    "/jobs",
    response_model=Dict[str, JobStatusResponse],
    summary="List all pipeline jobs",
)
def list_jobs() -> Dict[str, JobStatusResponse]:
    jobs = pipeline.list_jobs()
    return {jid: JobStatusResponse(**job) for jid, job in jobs.items()}
