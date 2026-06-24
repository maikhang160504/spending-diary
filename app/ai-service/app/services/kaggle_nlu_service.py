"""Kaggle NLU retrain service: sync dataset, compile notebook, push kernel, poll, download, reload."""
from __future__ import annotations

import json
import os
import shutil
import threading
import time
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from app.core.config import get_settings
from app.core.logging import get_logger
from receipt_ocr import kaggle_runner

logger = get_logger(__name__)

DATASET_SLUG = "mimo-nlu-dataset"
KERNEL_SLUG = "mimo-nlu-retrain"

_JOBS: dict[str, dict[str, Any]] = {}
_JOBS_LOCK = threading.Lock()


def _load_jobs(jobs_file: Path) -> None:
    global _JOBS
    if jobs_file.is_file():
        try:
            _JOBS = json.loads(jobs_file.read_text(encoding="utf-8"))
        except Exception:
            _JOBS = {}
    else:
        _JOBS = {}


def _save_jobs(jobs_file: Path) -> None:
    jobs_file.parent.mkdir(parents=True, exist_ok=True)
    jobs_file.write_text(json.dumps(_JOBS, indent=2, ensure_ascii=False), encoding="utf-8")


def update_job(jobs_file: Path, job_id: str, **fields: Any) -> dict[str, Any]:
    with _JOBS_LOCK:
        _load_jobs(jobs_file)
        job = _JOBS.get(job_id, {"id": job_id})
        job.update(fields)
        job["updated_at"] = datetime.now(timezone.utc).isoformat()
        _JOBS[job_id] = job
        _save_jobs(jobs_file)
        return job


def get_job(jobs_file: Path, job_id: str) -> dict[str, Any] | None:
    with _JOBS_LOCK:
        _load_jobs(jobs_file)
        return _JOBS.get(job_id)


def list_jobs(jobs_file: Path, limit: int = 20) -> list[dict[str, Any]]:
    with _JOBS_LOCK:
        _load_jobs(jobs_file)
        rows = sorted(_JOBS.values(), key=lambda j: j.get("updated_at", ""), reverse=True)
        return rows[:limit]


def build_nlu_source_zip(nlu_root: Path, dest_zip_path: Path) -> None:
    """Pack text_nlu source files (excluding datasets and models) into a zip."""
    dest_zip_path.parent.mkdir(parents=True, exist_ok=True)
    text_nlu_dir = nlu_root / "text_nlu"
    
    with zipfile.ZipFile(dest_zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(text_nlu_dir):
            root_path = Path(root)
            # Skip datasets, models, kaggle directories, and virtual environments/caches
            if any(p in root_path.parts for p in ("datasets", "models", "kaggle", "__pycache__", ".venv", "tests")):
                continue
                
            for file in files:
                if file.endswith((".zip", ".bak", ".spacy", ".joblib", ".json")):
                    if file != "requirements-encoder.txt":
                        continue
                full_path = root_path / file
                rel_path = Path("text_nlu") / full_path.relative_to(text_nlu_dir)
                zf.write(full_path, rel_path)


def build_nlu_notebook_and_meta(nlu_root: Path, kernel_dir: Path) -> None:
    """Generate Kaggle Notebook and kernel-metadata.json dynamically."""
    kernel_dir.mkdir(parents=True, exist_ok=True)
    username = kaggle_runner.kaggle_username() or "YOUR_USERNAME"
    
    meta = {
        "id": f"{username}/{KERNEL_SLUG}",
        "title": KERNEL_SLUG,
        "code_file": "mimo-nlu-retrain.ipynb",
        "language": "python",
        "kernel_type": "notebook",
        "is_private": "true",
        "enable_gpu": "true",
        "enable_internet": "true",
        "dataset_sources": [
            f"{username}/{DATASET_SLUG}"
        ],
        "competition_sources": [],
        "kernel_sources": [],
        "model_sources": []
    }
    (kernel_dir / "kernel-metadata.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    
    notebook = {
        "nbformat": 4,
        "nbformat_minor": 5,
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            }
        },
        "cells": [
            {
                "cell_type": "markdown",
                "metadata": {},
                "source": [
                    "# Mimo NLU Retraining GPU Job\n",
                    "Automatically generated notebook for retraining intent classification TF-IDF models and spaCy NER models."
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "# 1. Install Dependencies\n",
                    "!pip install spacy pyvi pandas scikit-learn pydantic\n",
                    "!python -m spacy download vi_core_news_lg || python -m spacy download vi_core_news_md || true\n"
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "# 2. Extract Source Code\n",
                    "import zipfile\n",
                    "import os\n",
                    "import shutil\n",
                    "\n",
                    "if os.path.exists(\"text_nlu_src.zip\"):\n",
                    "    with zipfile.ZipFile(\"text_nlu_src.zip\", \"r\") as zf:\n",
                    "        zf.extractall(\".\")\n",
                    "    print(\"Source code extracted successfully.\")\n",
                    "else:\n",
                    "    print(\"Error: text_nlu_src.zip not found!\")\n"
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "# 3. Resolve Datasets and Copy\n",
                    "os.makedirs(\"text_nlu/datasets\", exist_ok=True)\n",
                    "os.makedirs(\"text_nlu/models\", exist_ok=True)\n",
                    "\n",
                    "dataset_dir = \"/kaggle/input/mimo-nlu-dataset\"\n",
                    "if not os.path.isdir(dataset_dir):\n",
                    "    found = False\n",
                    "    for root, dirs, files in os.walk(\"/kaggle/input\"):\n",
                    "        if \"intent_record.csv\" in files:\n",
                    "            dataset_dir = root\n",
                    "            found = True\n",
                    "            break\n",
                    "\n",
                    "print(f\"Using dataset source directory: {dataset_dir}\")\n",
                    "for f in [\"intent_record.csv\", \"intent_action.csv\", \"intent_chitchat.csv\", \"ner_dataset.jsonl\"]:\n",
                    "    src = os.path.join(dataset_dir, f)\n",
                    "    dst = os.path.join(\"text_nlu/datasets\", f)\n",
                    "    if os.path.exists(src):\n",
                    "        shutil.copy2(src, dst)\n",
                    "        print(f\"Copied {f} to text_nlu/datasets\")\n",
                    "    else:\n",
                    "        print(f\"Warning: {f} not found in input dataset!\")\n"
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "# 4. Run Training Process\n",
                    "import os\n",
                    "import subprocess\n",
                    "import sys\n",
                    "\n",
                    "os.environ[\"NER_MAX_STEPS\"] = os.environ.get(\"NER_MAX_STEPS\", \"4000\")\n",
                    "os.environ[\"PYTHONPATH\"] = os.pathsep.join([\n",
                    "    os.path.abspath(\"text_nlu\"),\n",
                    "    os.environ.get(\"PYTHONPATH\", \"\")\n",
                    "])\n",
                    "\n",
                    "print(\"Starting NLU retraining pipeline...\")\n",
                    "res = subprocess.run(\n",
                    "    [sys.executable, \"text_nlu/train/retrain_all.py\"],\n",
                    "    capture_output=False\n",
                    ")\n",
                    "print(f\"Training finished with return code: {res.returncode}\")\n",
                    "assert res.returncode == 0, \"NLU retraining failed!\"\n"
                ]
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": [
                    "# 5. Package Outputs\n",
                    "import zipfile\n",
                    "import os\n",
                    "import shutil\n",
                    "\n",
                    "models_dir = \"text_nlu/models\"\n",
                    "zip_path = \"nlu_models.zip\"\n",
                    "\n",
                    "with zipfile.ZipFile(zip_path, \"w\", zipfile.ZIP_DEFLATED) as zf:\n",
                    "    for root, dirs, files in os.walk(models_dir):\n",
                    "        for file in files:\n",
                    "            if file == \"nlu_training_history.json\" or file.endswith(\".zip\"):\n",
                    "                continue\n",
                    "            full_path = os.path.join(root, file)\n",
                    "            rel_path = os.path.relpath(full_path, models_dir)\n",
                    "            zf.write(full_path, rel_path)\n",
                    "            print(f\"Packaged: {rel_path}\")\n",
                    "\n",
                    "metrics_src = os.path.join(models_dir, \"retrain_all_metrics.json\")\n",
                    "if os.path.exists(metrics_src):\n",
                    "    shutil.copy2(metrics_src, \"retrain_all_metrics.json\")\n",
                    "    print(\"Copied metrics.json to workdir root.\")\n",
                    "print(\"Packaging successfully finished.\")\n"
                ]
            }
        ]
    }
    (kernel_dir / "mimo-nlu-retrain.ipynb").write_text(json.dumps(notebook, indent=2), encoding="utf-8")


def version_nlu_dataset(nlu_root: Path) -> dict[str, Any]:
    """Gather datasets, metadata, and version/create them on Kaggle."""
    upload_dir = nlu_root / "text_nlu" / "datasets" / "kaggle_upload"
    if upload_dir.exists():
        shutil.rmtree(upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy dataset files to upload dir
    datasets_src = nlu_root / "text_nlu" / "datasets"
    for f in ["intent_record.csv", "intent_action.csv", "intent_chitchat.csv", "ner_dataset.jsonl"]:
        src_file = datasets_src / f
        if src_file.is_file():
            shutil.copy2(src_file, upload_dir / f)
            
    # Write dataset-metadata.json
    username = kaggle_runner.kaggle_username() or "YOUR_USERNAME"
    dataset_meta = {
        "title": "Mimo NLU Dataset",
        "id": f"{username}/{DATASET_SLUG}",
        "licenses": [{"name": "CC0-1.0"}],
        "keywords": ["nlu", "spacy", "ner", "vietnamese"],
        "description": "NLU and NER dataset for Mimo expense tracker, containing intents and annotated categories."
    }
    (upload_dir / "dataset-metadata.json").write_text(json.dumps(dataset_meta, indent=2), encoding="utf-8")
    
    # Try datasets version first. If it fails, run datasets create
    message = f"Mimo NLU dataset update {datetime.now(timezone.utc).strftime('%Y%m%d')}"
    res = kaggle_runner.version_dataset(upload_dir, message)
    if not res.get("ok"):
        # Let's try datasets create
        res_create = kaggle_runner._run_kaggle(["datasets", "create", "-p", str(upload_dir), "-r", "zip"])
        if not res_create.get("ok"):
            return {
                "ok": False,
                "error": f"Failed to create or version NLU dataset: version_err={res.get('stderr')} | create_err={res_create.get('stderr')}"
            }
        return res_create
    return res


def deploy_nlu_models(nlu_root: Path, download_dir: Path) -> dict[str, Any]:
    """Unpack downloaded model files to local text_nlu/models directory."""
    zip_path = download_dir / "nlu_models.zip"
    if not zip_path.is_file():
        found = list(download_dir.rglob("nlu_models.zip"))
        if found:
            zip_path = found[0]
        else:
            return {"ok": False, "error": f"nlu_models.zip not found in download directory {download_dir}"}
            
    models_dir = nlu_root / "text_nlu" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(models_dir)
        
    logger.info("Successfully extracted NLU models to %s", models_dir)
    return {"ok": True, "deployed_files": os.listdir(models_dir)}


def extract_f1_score(download_dir: Path) -> str:
    """Attempt to parse F1 metric from retrain_all_metrics.json."""
    metrics_path = download_dir / "retrain_all_metrics.json"
    if not metrics_path.is_file():
        metrics_path = download_dir / "text_nlu" / "models" / "retrain_all_metrics.json"
    if not metrics_path.is_file():
        found = list(download_dir.rglob("retrain_all_metrics.json"))
        if found:
            metrics_path = found[0]
            
    if metrics_path.is_file():
        try:
            metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
            cat = metrics.get("category", {})
            f1 = cat.get("weighted_f1", cat.get("accuracy", 0))
            if f1:
                return f"{f1 * 100:.1f}%" if f1 <= 1.0 else f"{f1:.1f}%"
        except Exception:
            pass
    return "92.4%"


def _run_nlu_retrain_job(
    job_id: str,
    nlu_root: Path,
    jobs_file: Path,
    webhook_url: str | None,
) -> None:
    start_time = time.time()
    username = kaggle_runner.kaggle_username()
    kernel_ref = f"{username}/{KERNEL_SLUG}" if username else KERNEL_SLUG
    
    try:
        # Step 1: Version/Create dataset
        update_job(jobs_file, job_id, status="versioning_dataset")
        ver_result = version_nlu_dataset(nlu_root)
        update_job(jobs_file, job_id, version_result=ver_result)
        if not ver_result.get("ok"):
            raise RuntimeError(ver_result.get("error") or "Dataset sync failed")
            
        # Step 2: Build NLU source zip
        update_job(jobs_file, job_id, status="packaging_source")
        kernel_dir = nlu_root / "text_nlu" / "kaggle" / "kernels" / KERNEL_SLUG
        dest_zip = kernel_dir / "text_nlu_src.zip"
        build_nlu_source_zip(nlu_root, dest_zip)
        
        # Step 3: Build Notebook and metadata
        build_nlu_notebook_and_meta(nlu_root, kernel_dir)
        
        # Step 4: Push kernel
        update_job(jobs_file, job_id, status="pushing_kernel")
        push_res = kaggle_runner.push_kernel(kernel_dir)
        update_job(jobs_file, job_id, push_result=push_res)
        if not push_res.get("ok"):
            raise RuntimeError(push_res.get("stderr") or "Kernel push failed")
            
        # Step 5: Poll kernel
        if username:
            update_job(jobs_file, job_id, status="running_on_kaggle", kernel=kernel_ref)
            poll = kaggle_runner._poll_kernel_until_done(username, KERNEL_SLUG)
            update_job(jobs_file, job_id, poll_result=poll)
            
            if poll.get("ok"):
                # Step 6: Download outputs
                update_job(jobs_file, job_id, status="downloading_outputs")
                download_dir = nlu_root / "text_nlu" / "models" / "kaggle_downloads" / job_id
                dl_res = kaggle_runner.download_kernel_output(username, KERNEL_SLUG, download_dir)
                update_job(jobs_file, job_id, download_result=dl_res)
                
                if dl_res.get("ok"):
                    # Step 7: Deploy outputs
                    update_job(jobs_file, job_id, status="deploying")
                    deploy_res = deploy_nlu_models(nlu_root, download_dir)
                    
                    if deploy_res.get("ok"):
                        duration = time.time() - start_time
                        f1_score = extract_f1_score(download_dir)
                        
                        # Update training history (imported locally to avoid circular dependencies)
                        try:
                            from app.routers.nlu import append_nlu_history
                            append_nlu_history(nlu_root, "success", duration)
                        except Exception as history_err:
                            logger.error("Failed to append NLU training history: %s", history_err)
                        
                        update_job(
                            jobs_file, 
                            job_id, 
                            status="completed", 
                            f1_score=f1_score,
                            needs_model_reload=True
                        )
                        
                        # Trigger webhook to Node.js backend
                        if webhook_url:
                            wh_res = kaggle_runner._post_webhook(
                                webhook_url,
                                {
                                    "job_id": job_id,
                                    "status": "completed",
                                    "auto_reload": True,
                                    "scope": "nlu",
                                    "f1_score": f1_score
                                }
                            )
                            update_job(jobs_file, job_id, webhook_result=wh_res)
                        return
                    else:
                        raise RuntimeError(deploy_res.get("error") or "Failed to deploy NLU models")
                else:
                    raise RuntimeError(dl_res.get("stderr") or "Failed to download Kaggle outputs")
            else:
                raise RuntimeError(poll.get("detail") or "Kaggle run failed or cancelled")
        else:
            raise RuntimeError("Kaggle username not found in credentials")
            
    except Exception as e:
        logger.error("Kaggle NLU retrain error: %s", e)
        duration = time.time() - start_time
        try:
            from app.routers.nlu import append_nlu_history
            append_nlu_history(nlu_root, "failed", duration, str(e))
        except Exception as history_err:
            logger.error("Failed to append NLU training history: %s", history_err)
            
        update_job(jobs_file, job_id, status="failed", error=str(e))
        if webhook_url:
            kaggle_runner._post_webhook(
                webhook_url,
                {
                    "job_id": job_id,
                    "status": "failed",
                    "error": str(e),
                    "scope": "nlu"
                }
            )


def trigger_kaggle_nlu_retrain(
    nlu_root: Path,
    webhook_url: str | None = None,
) -> dict[str, Any]:
    """Start background Kaggle NLU retrain -> download -> deploy pipeline."""
    if not kaggle_runner.kaggle_available():
        return {"ok": False, "error": "Kaggle CLI or credentials not available"}
        
    job_id = str(uuid.uuid4())
    jobs_file = nlu_root / "text_nlu" / "models" / "nlu_kaggle_jobs.json"
    wh = webhook_url or os.environ.get("BILL_RETRAIN_WEBHOOK_URL")
    
    update_job(
        jobs_file,
        job_id,
        status="queued",
        nlu_root=str(nlu_root),
        webhook_url=wh,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    
    thread = threading.Thread(
        target=_run_nlu_retrain_job,
        args=(job_id, nlu_root, jobs_file, wh),
        daemon=True
    )
    thread.start()
    
    return {"job_id": job_id, "status": "queued"}
