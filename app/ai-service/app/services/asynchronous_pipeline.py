"""Asynchronous multi-stage pipeline service using asyncio.Queue and in-memory tracker."""
from __future__ import annotations

import asyncio
import datetime
import logging
import uuid
from typing import Any, Dict, Optional

from app.services.ocr_service import get_ocr_service
from app.services.expense_service import get_expense_service

logger = logging.getLogger(__name__)

# Job storage
_JOBS: Dict[str, Dict[str, Any]] = {}
_IMAGE_STORE: Dict[str, bytes] = {}
_FILENAME_STORE: Dict[str, Optional[str]] = {}

# Queues for 5 stages
queue_stage1: asyncio.Queue[str] = asyncio.Queue()
queue_stage2: asyncio.Queue[str] = asyncio.Queue()
queue_stage3: asyncio.Queue[str] = asyncio.Queue()
queue_stage4: asyncio.Queue[str] = asyncio.Queue()
queue_stage5: asyncio.Queue[str] = asyncio.Queue()

# Background worker tasks
_worker_tasks: list[asyncio.Task] = []
_running = False


def get_job(job_id: str) -> Optional[Dict[str, Any]]:
    """Retrieve status and result of a pipeline job."""
    return _JOBS.get(job_id)


def list_jobs() -> Dict[str, Dict[str, Any]]:
    """List all pipeline jobs."""
    return _JOBS


def submit_job(image_bytes: bytes, filename: Optional[str] = None) -> str:
    """Submit a new receipt processing job to the asynchronous pipeline."""
    job_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    
    _JOBS[job_id] = {
        "job_id": job_id,
        "status": "pending",
        "current_stage": "None",
        "progress": 0,
        "created_at": now,
        "updated_at": now,
        "result": None,
        "error": None
    }
    
    # Store the image data in-memory associated with the job_id
    # (avoid passing raw binary buffer in the queue payload)
    _IMAGE_STORE[job_id] = image_bytes
    _FILENAME_STORE[job_id] = filename
    
    # Push job_id into Stage 1 queue
    print(f"[DEBUG] submit_job: job {job_id} submitted. Putting in queue_stage1...", flush=True)
    queue_stage1.put_nowait(job_id)
    print(f"[DEBUG] submit_job: put complete. queue_stage1 size: {queue_stage1.qsize()}", flush=True)
    logger.info("Submitted job %s to asynchronous pipeline.", job_id)
    
    return job_id


async def worker_stage1():
    """Stage 1: Image Prep & Rotation Corrector worker."""
    print("[DEBUG] worker_stage1 task started", flush=True)
    while _running:
        print("[DEBUG] worker_stage1 waiting for job...", flush=True)
        job_id = await queue_stage1.get()
        print(f"[DEBUG] worker_stage1 got job: {job_id}", flush=True)
        try:
            if job_id not in _JOBS:
                print(f"[DEBUG] worker_stage1: job {job_id} not in jobs list!", flush=True)
                queue_stage1.task_done()
                continue
                
            logger.info("[Job %s] Stage 1: Image Prep & Rotation Corrector starting...", job_id)
            _update_job(job_id, status="processing", current_stage="Stage_1_Rotation", progress=20)
            
            # Simulate processing delay
            await asyncio.sleep(0.2)
            
            # Real or simulated check: load image and verify integrity
            image_data = _IMAGE_STORE.get(job_id)
            if not image_data:
                raise ValueError("Image bytes not found in store.")
                
            logger.info("[Job %s] Stage 1 completed successfully.", job_id)
            print(f"[DEBUG] worker_stage1: job {job_id} complete. Putting in queue_stage2...", flush=True)
            await queue_stage2.put(job_id)
        except Exception as exc:
            logger.error("[Job %s] Stage 1 failed: %s", job_id, exc)
            _mark_job_failed(job_id, f"Stage 1 error: {exc}")
        finally:
            queue_stage1.task_done()


async def worker_stage2():
    """Stage 2: OCR Detection (PaddleOCR) worker."""
    while _running:
        job_id = await queue_stage2.get()
        try:
            if job_id not in _JOBS or _JOBS[job_id]["status"] == "failed":
                queue_stage2.task_done()
                continue
                
            logger.info("[Job %s] Stage 2: OCR Detection starting...", job_id)
            _update_job(job_id, current_stage="Stage_2_Detection", progress=40)
            
            # Simulate processing delay
            await asyncio.sleep(0.2)
            
            logger.info("[Job %s] Stage 2 completed successfully.", job_id)
            await queue_stage3.put(job_id)
        except Exception as exc:
            logger.error("[Job %s] Stage 2 failed: %s", job_id, exc)
            _mark_job_failed(job_id, f"Stage 2 error: {exc}")
        finally:
            queue_stage2.task_done()


async def worker_stage3():
    """Stage 3: OCR Recognition (VietOCR) worker."""
    while _running:
        job_id = await queue_stage3.get()
        try:
            if job_id not in _JOBS or _JOBS[job_id]["status"] == "failed":
                queue_stage3.task_done()
                continue
                
            logger.info("[Job %s] Stage 3: OCR Recognition starting...", job_id)
            _update_job(job_id, current_stage="Stage_3_Recognition", progress=60)
            
            # Simulate processing delay
            await asyncio.sleep(0.3)
            
            logger.info("[Job %s] Stage 3 completed successfully.", job_id)
            await queue_stage4.put(job_id)
        except Exception as exc:
            logger.error("[Job %s] Stage 3 failed: %s", job_id, exc)
            _mark_job_failed(job_id, f"Stage 3 error: {exc}")
        finally:
            queue_stage3.task_done()


async def worker_stage4():
    """Stage 4: PICK KIE & Fusion worker."""
    while _running:
        job_id = await queue_stage4.get()
        try:
            if job_id not in _JOBS or _JOBS[job_id]["status"] == "failed":
                queue_stage4.task_done()
                continue
                
            logger.info("[Job %s] Stage 4: PICK KIE & Fusion starting...", job_id)
            _update_job(job_id, current_stage="Stage_4_KIE", progress=80)
            
            # Simulate processing delay
            await asyncio.sleep(0.2)
            
            logger.info("[Job %s] Stage 4 completed successfully.", job_id)
            await queue_stage5.put(job_id)
        except Exception as exc:
            logger.error("[Job %s] Stage 4 failed: %s", job_id, exc)
            _mark_job_failed(job_id, f"Stage 4 error: {exc}")
        finally:
            queue_stage4.task_done()


async def worker_stage5():
    """Stage 5: NLU & LLM Story worker."""
    while _running:
        job_id = await queue_stage5.get()
        try:
            if job_id not in _JOBS or _JOBS[job_id]["status"] == "failed":
                queue_stage5.task_done()
                continue
                
            logger.info("[Job %s] Stage 5: NLU & LLM Story starting...", job_id)
            _update_job(job_id, current_stage="Stage_5_NLU_LLM", progress=100)
            
            image_data = _IMAGE_STORE.get(job_id)
            filename = _FILENAME_STORE.get(job_id)
            if not image_data:
                raise ValueError("Image bytes not found in store.")
            
            # Execute actual extraction logic using expense service (handles mock vs real transparently)
            loop = asyncio.get_running_loop()
            response = await loop.run_in_executor(
                None, get_expense_service().from_image, image_data, filename
            )
            
            # Convert response to dictionary representation
            result_dict = response.model_dump()
            
            _update_job(job_id, status="completed", result=result_dict)
            logger.info("[Job %s] Stage 5 completed successfully. Job finalized.", job_id)
        except Exception as exc:
            logger.error("[Job %s] Stage 5 failed: %s", job_id, exc)
            _mark_job_failed(job_id, f"Stage 5 error: {exc}")
        finally:
            # Clean up raw image data from memory to prevent leaks
            _IMAGE_STORE.pop(job_id, None)
            _FILENAME_STORE.pop(job_id, None)
            queue_stage5.task_done()


def _update_job(job_id: str, **kwargs):
    if job_id in _JOBS:
        _JOBS[job_id].update(kwargs)
        _JOBS[job_id]["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def _mark_job_failed(job_id: str, error_msg: str):
    _update_job(job_id, status="failed", error=error_msg)
    _IMAGE_STORE.pop(job_id, None)
    _FILENAME_STORE.pop(job_id, None)


def start_pipeline():
    """Start background workers for the 5-stage pipeline."""
    global _running, _worker_tasks
    print(f"[DEBUG] start_pipeline called. _running={_running}", flush=True)
    if _running:
        return
        
    _running = True
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.get_event_loop()
    print(f"[DEBUG] start_pipeline: scheduling tasks on loop {id(loop)}", flush=True)
    
    _worker_tasks = [
        loop.create_task(worker_stage1()),
        loop.create_task(worker_stage2()),
        loop.create_task(worker_stage3()),
        loop.create_task(worker_stage4()),
        loop.create_task(worker_stage5()),
    ]
    print("[DEBUG] start_pipeline: 5 tasks scheduled successfully.", flush=True)
    logger.info("Asynchronous pipeline 5-stage workers started.")


def stop_pipeline():
    """Stop background workers."""
    global _running, _worker_tasks
    if not _running:
        return
        
    _running = False
    for task in _worker_tasks:
        task.cancel()
    _worker_tasks.clear()
    logger.info("Asynchronous pipeline 5-stage workers stopped.")
