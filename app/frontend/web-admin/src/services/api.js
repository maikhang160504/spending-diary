const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";
const BILL_OCR_TIMEOUT_MS = 300000;

function getAuthToken() {
  return localStorage.getItem("admin_token");
}

function handleAuthError(status, path = "") {
  if (status === 401 && !path.includes("/auth/login") && !path.includes("/login")) {
    localStorage.removeItem("admin_token");
    window.location.href = "/login";
  }
}

async function fetchMultipart(path, form, timeoutMs = BILL_OCR_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const token = getAuthToken();
  try {
    const response = await fetch(`${API_BASE_URL}${path}`, {
      method: "POST",
      body: form,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {})
      },
      signal: controller.signal,
    });
    if (!response.ok) {
      handleAuthError(response.status, path);
      const err = await response.json().catch(() => ({}));
      throw new Error(err.message || "Request failed");
    }
    return response.json();
  } catch (err) {
    if (err.name === "AbortError") {
      throw new Error("OCR timeout — thử lại hoặc bấm Tải lại model OCR trước.");
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

async function fetchJson(path, options = {}, timeoutMs = 60000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const token = getAuthToken();
  try {
    const response = await fetch(`${API_BASE_URL}${path}`, {
      headers: { 
        "Content-Type": "application/json", 
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(options.headers || {}) 
      },
      ...options,
      signal: controller.signal,
    });
    if (!response.ok) {
      handleAuthError(response.status, path);
      const err = await response.json().catch(() => ({}));
      throw new Error(err.message || "API request failed");
    }
    return response.json();
  } catch (err) {
    if (err.name === "AbortError") {
      throw new Error("Request timeout — thử lại.");
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

async function request(path, options = {}) {
  const token = getAuthToken();
  const { headers, ...restOptions } = options;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: { 
      "Content-Type": "application/json", 
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers || {}) 
    },
    ...restOptions
  });

  if (!response.ok) {
    handleAuthError(response.status, path);
    const errorPayload = await response.json().catch(() => ({}));
    throw new Error(errorPayload.message || "API request failed");
  }

  return response.json();
}

export async function loginAdmin(email, password) {
  const res = await fetch(`${API_BASE_URL}/api/v1/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password })
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || "Login failed");
  }
  const data = await res.json();
  if (data.data.user?.role !== "admin") {
    throw new Error("Access denied: Not an admin");
  }
  localStorage.setItem("admin_token", data.data.accessToken);
  return data.data;
}

export async function getAdminAnalytics() {
  return request("/api/admin/analytics");
}

export async function getAdminAnalyticsHistory(days = 7) {
  return request(`/api/admin/analytics/history?days=${days}`);
}

export async function getRetrainReadiness() {
  return request("/api/admin/retrain-readiness");
}

export async function getAdminUsers() {
  return request("/api/admin/users");
}

export async function getUserInspector(userId) {
  return request(`/api/admin/user-inspector/${userId}`);
}

export async function clearUserCache(userId) {
  return request(`/api/admin/cache/clear/${userId}`, {
    method: "POST"
  });
}

export async function getNluOverrides() {
  return request("/api/admin/nlu/overrides");
}

export async function addNluOverride(userId, keyword, categoryCode) {
  return request("/api/admin/nlu/overrides", {
    method: "POST",
    body: JSON.stringify({ userId, keyword, categoryCode })
  });
}

export async function deleteNluOverride(userId, keyword) {
  return request(`/api/admin/nlu/overrides/${userId}/${encodeURIComponent(keyword)}`, {
    method: "DELETE"
  });
}

/** Preview (confirm=false) or delete invalid Layer 1 rules (confirm=true). */
export async function cleanupInvalidNluOverrides(confirm = false) {
  return request("/api/admin/nlu/overrides/cleanup-invalid", {
    method: "POST",
    body: JSON.stringify({ confirm }),
  });
}


export async function getBotPrompts() {
  return request("/api/admin/prompts");
}

export async function saveBotPrompts(prompts) {
  return request("/api/admin/prompts", {
    method: "POST",
    body: JSON.stringify(prompts)
  });
}

export async function testSystemPrompt(payload) {
  return request("/api/admin/prompts/test", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export async function triggerNluTrain(target = "local", retrainPassword) {
  return request("/api/admin/train", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ target, retrainPassword })
  });
}

export async function fetchNluKaggleJobs(limit = 20) {
  return request(`/api/admin/train/kaggle/jobs?limit=${limit}`);
}

export async function fetchNluKaggleJob(jobId) {
  return request(`/api/admin/train/kaggle/jobs/${jobId}`);
}


export async function getNluTrainStatus() {
  return request("/api/admin/train/status");
}

export async function getBillTrainStatus() {
  return request("/api/admin/bill-retrain/train/status");
}

export async function resumeNluKaggle() {
  return request("/api/admin/train/kaggle/resume", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
}

export async function trainEncoderKaggle(retrainPassword) {
  return request("/api/admin/train/kaggle/encoder", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ retrainPassword })
  });
}

export async function getNluInferenceBackend() {
  return request("/api/admin/train/inference-backend");
}

export async function setNluInferenceBackend(payload, retrainPassword) {
  return request("/api/admin/train/inference-backend", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...payload, retrainPassword }),
  });
}

export async function syncNluKaggle(skipDownload = false) {
  return request("/api/admin/train/kaggle/sync", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ skipDownload }),
  });
}

export async function syncNluEncoderKaggle(skipDownload = false) {
  return request("/api/admin/train/kaggle/encoder/sync", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ skipDownload }),
  });
}

export async function getNluModelMeta() {
  return request("/api/admin/train/model-meta");
}

export async function getNluModelsStatus() {
  return request("/api/admin/train/models/status");
}

export async function promoteNluModel(retrainPassword) {
  return request("/api/admin/train/promote", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ retrainPassword }),
  });
}
export async function exportFinetuneData() {
  const token = getAuthToken();
  const res = await fetch(`${API_BASE_URL}/api/admin/train/export-finetune`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    }
  });
  if (!res.ok) {
    handleAuthError(res.status, "/api/admin/train/export-finetune");
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || "Xuất tập dữ liệu thất bại");
  }
  const blob = await res.blob();
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "mimo_nlu_finetune.jsonl";
  document.body.appendChild(a);
  a.click();
  a.remove();
}



export async function getNluTrainHistory() {
  return request("/api/admin/train/history");
}

export function fetchBillOcrStatus() {
  return request("/api/admin/bill-retrain/ocr-status");
}

export function deleteBillSample(id) {
  return request(`/api/admin/bill-retrain/samples/${id}`, { method: "DELETE" });
}

export function rePrelabelBillSample(id) {
  return fetchJson(`/api/admin/bill-retrain/samples/${id}/prelabel`, { method: "POST" }, BILL_OCR_TIMEOUT_MS);
}

export function fetchBillSamples(status) {
  const q = status ? `?status=${encodeURIComponent(status)}` : "";
  return request(`/api/admin/bill-retrain/samples${q}`);
}

export function uploadBillSample(file) {
  const form = new FormData();
  form.append("file", file);
  return fetchMultipart("/api/admin/bill-retrain/upload", form, 120000);
}

export function prelabelBill(file) {
  const form = new FormData();
  form.append("file", file);
  return fetchMultipart("/api/admin/bill-retrain/prelabel", form, BILL_OCR_TIMEOUT_MS);
}

export function saveBillSample(id, adminLabels, status = "pending", category = null) {
  return request(`/api/admin/bill-retrain/samples/${id}`, {
    method: "PUT",
    body: JSON.stringify({ adminLabels, status, category }),
  });
}

export function approveBillSample(id, adminLabels, category = null) {
  return request(`/api/admin/bill-retrain/samples/${id}/approve`, {
    method: "POST",
    body: JSON.stringify({ adminLabels, category }),
  });
}

export function billRetrainKaggleWebhookUrl() {
  return `${API_BASE_URL}/api/admin/bill-retrain/kaggle/webhook`;
}

export function exportBillVerified(
  triggerKaggle = false,
  kaggleJobType = "pick_retrain",
  webhookUrl,
  archiveImages = true
) {
  return request("/api/admin/bill-retrain/export", {
    method: "POST",
    body: JSON.stringify({
      triggerKaggle,
      kaggleJobType,
      webhookUrl: webhookUrl || billRetrainKaggleWebhookUrl(),
      archiveImages,
    }),
  });
}

export function fetchBillKagglePlan(jobType = "pick_retrain") {
  return request("/api/admin/bill-retrain/kaggle/plan", {
    method: "POST",
    body: JSON.stringify({ jobType }),
  });
}

export function triggerBillKaggle(jobType = "pick_retrain", webhookUrl, cloudUrl) {
  return request("/api/admin/bill-retrain/kaggle/trigger", {
    method: "POST",
    body: JSON.stringify({
      jobType,
      webhookUrl: webhookUrl || billRetrainKaggleWebhookUrl(),
      cloudFallbackUrl: cloudUrl,
    }),
  });
}

export function fetchBillKaggleJob(jobId) {
  return request(`/api/admin/bill-retrain/kaggle/jobs/${jobId}`);
}

export function fetchBillKaggleJobs(limit = 20) {
  return request(`/api/admin/bill-retrain/kaggle/jobs?limit=${limit}`);
}

export function syncBillKaggle(skipDownload = false, jobType = "pick_retrain") {
  return request("/api/admin/bill-retrain/kaggle/sync", {
    method: "POST",
    body: JSON.stringify({ skipDownload, jobType }),
  });
}

export function runBillGoldenEval() {
  return request("/api/admin/bill-retrain/golden-eval");
}

export function triggerBillModal(numEpochs = 30, learningRate = 0.00002, retrainPassword) {
  return request("/api/admin/bill-retrain/modal/trigger", {
    method: "POST",
    body: JSON.stringify({ numEpochs, learningRate, retrainPassword }),
  });
}

export function reloadAiModels(scope = "ocr") {
  return request("/api/admin/ai-service/reload", {
    method: "POST",
    body: JSON.stringify({ scope }),
  });
}

export function billSampleImageUrl(id) {
  const token = getAuthToken();
  return `${API_BASE_URL}/api/admin/bill-retrain/samples/${id}/image?token=${token}`;
}

export function getSystemStatus() {
  return request("/api/admin/system/status");
}

export function getSystemSettings() {
  return request("/api/admin/settings");
}

export function saveSystemSettings(settings) {
  return request("/api/admin/settings", {
    method: "POST",
    body: JSON.stringify(settings)
  });
}

export function importNluCsv(file, autoRetrain = false, trainTarget = "local") {
  const form = new FormData();
  form.append("file", file);
  form.append("autoRetrain", autoRetrain.toString());
  form.append("trainTarget", trainTarget);
  return fetch(`${API_BASE_URL}/api/admin/nlu/import-csv`, {
    method: "POST",
    body: form,
  }).then(async (res) => {
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || "Import failed");
    }
    return res.json();
  });
}

export function getNluBenchmarkResults() {
  return request("/api/admin/nlu/benchmark/results");
}

export function triggerNluBenchmark() {
  return request("/api/admin/nlu/benchmark/run", {
    method: "POST"
  });
}

export function getLlmTrainHistory() {
  return request("/api/admin/train/llm-history");
}

export function getOcrTrainHistory() {
  return request("/api/admin/bill-retrain/ocr-history");
}

export function triggerLlmFinetune(epochs = 3, lr = 0.0002, batchSize = 4, retrainPassword) {
  return request("/api/admin/train/llm-trigger", {
    method: "POST",
    body: JSON.stringify({ epochs, lr, batchSize, retrainPassword })
  });
}

export function getLlmTrainStatus() {
  return request("/api/admin/train/llm-status");
}

export function getMonetizationStats() {
  return request("/api/admin/monetization/stats");
}

export function getMonetizationHistory(days = 30) {
  return request(`/api/admin/monetization/history?days=${days}`);
}

export function getMonetizationOrders(limit = 100) {
  return request(`/api/admin/monetization/orders?limit=${limit}`);
}

export function toggleUserPremium(userId, isPremium) {
  return request(`/api/admin/users/${userId}/premium`, {
    method: "POST",
    body: JSON.stringify({ isPremium })
  });
}

export function getBillModelCandidate() {
  return request("/api/admin/bill-retrain/model/candidate");
}


export function rollbackNluModel(retrainPassword) {
  return request("/api/admin/train/rollback", {
    method: "POST",
    body: JSON.stringify({ retrainPassword })
  });
}

export function promoteBillModel(retrainPassword) {
  return request("/api/admin/bill-retrain/model/promote", {
    method: "POST",
    body: JSON.stringify({ retrainPassword })
  });
}

export function rollbackBillModel(retrainPassword) {
  return request("/api/admin/bill-retrain/model/rollback", {
    method: "POST",
    body: JSON.stringify({ retrainPassword })
  });
}

export function syncBillModelWorkspace(retrainPassword) {
  return request("/api/admin/bill-retrain/model/sync-workspace", {
    method: "POST",
    body: JSON.stringify({ retrainPassword })
  });
}
