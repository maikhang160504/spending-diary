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

