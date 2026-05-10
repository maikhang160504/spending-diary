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

export async function getUserExpenses(userId = 1) {
  return request(`/api/user/expenses?userId=${userId}`);
}

export async function getAdminAiLogs() {
  return request("/api/admin/ai-logs");
}

export async function postUserChat(message) {
  return request("/api/user/chat", {
    method: "POST",
    body: JSON.stringify({ message, userId: 1 })
  });
}
