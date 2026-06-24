const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:4000";

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {})
    },
    ...options
  });

  if (!response.ok) {
    const errorPayload = await response.json().catch(() => ({}));
    throw new Error(errorPayload.message || "API request failed");
  }

  return response.json();
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

export async function getNluAggregations() {
  return request("/api/admin/nlu/aggregations");
}

export async function curateNluAggregations(corrections, autoRetrain = false) {
  return request("/api/admin/nlu/curate", {
    method: "POST",
    body: JSON.stringify({ corrections, autoRetrain })
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

export async function triggerNluTrain() {
  return request("/api/admin/train", {
    method: "POST"
  });
}

export async function getNluTrainStatus() {
  return request("/api/admin/train/status");
}

export async function getNluModelMeta() {
  return request("/api/admin/train/model-meta");
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
  return request(`/api/admin/bill-retrain/samples/${id}/prelabel`, { method: "POST" });
}

export function fetchBillSamples(status) {
  const q = status ? `?status=${encodeURIComponent(status)}` : "";
  return request(`/api/admin/bill-retrain/samples${q}`);
}

export function uploadBillSample(file) {
  const form = new FormData();
  form.append("file", file);
  return fetch(`${API_BASE_URL}/api/admin/bill-retrain/upload`, {
    method: "POST",
    body: form,
  }).then(async (res) => {
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || "Upload failed");
    }
    return res.json();
  });
}

export function prelabelBill(file) {
  const form = new FormData();
  form.append("file", file);
  return fetch(`${API_BASE_URL}/api/admin/bill-retrain/prelabel`, {
    method: "POST",
    body: form,
  }).then(async (res) => {
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || "Prelabel failed");
    }
    return res.json();
  });
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

export function runBillGoldenEval() {
  return request("/api/admin/bill-retrain/golden-eval");
}

export function reloadAiModels(scope = "ocr") {
  return request("/api/admin/ai-service/reload", {
    method: "POST",
    body: JSON.stringify({ scope }),
  });
}

export function billSampleImageUrl(id) {
  return `${API_BASE_URL}/api/admin/bill-retrain/samples/${id}/image`;
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

export function importNluCsv(file, autoRetrain = false) {
  const form = new FormData();
  form.append("file", file);
  form.append("autoRetrain", autoRetrain.toString());
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

