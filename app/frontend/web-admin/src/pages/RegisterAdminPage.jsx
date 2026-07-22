import { useState } from "react";
import { useNavigate } from "react-router-dom";

function RegisterAdminPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loading, setLoading] = useState(false);

  const handleRegister = async (e) => {
    e.preventDefault();
    setError("");
    setSuccess("");
    setLoading(true);
    try {
      const token = localStorage.getItem("admin_token");
      const res = await fetch(import.meta.env.VITE_API_BASE_URL + "/api/admin/create-admin" || "http://localhost:4000/api/admin/create-admin", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        body: JSON.stringify({ email, password, username })
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.message || "Tạo tài khoản thất bại");
      }
      setSuccess(data.message || "Đã tạo tài khoản quản trị thành công!");
      setEmail("");
      setPassword("");
      setUsername("");
    } catch (err) {
      setError(err.message || "Tạo tài khoản thất bại");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      maxWidth: "600px",
      margin: "0 auto",
      padding: "2rem"
    }}>
      <div style={{ marginBottom: "2rem" }}>
        <h2 style={{ fontSize: "1.5rem", fontWeight: "600", color: "var(--text-primary)" }}>Thêm Quản trị viên mới</h2>
        <p style={{ color: "var(--text-secondary)", marginTop: "0.5rem" }}>
          Tạo tài khoản với quyền Admin (Chỉ có Admin hiện tại mới thực hiện được tính năng này).
        </p>
      </div>

      <div style={{
        backgroundColor: "var(--bg-obsidian-900)",
        borderRadius: "12px",
        padding: "2rem",
        border: "1px solid var(--border-color)",
      }}>
        {error && (
          <div style={{
            padding: "1rem",
            marginBottom: "1.5rem",
            backgroundColor: "var(--accent-rose-glow)",
            color: "var(--accent-rose)",
            borderRadius: "8px",
            fontSize: "0.875rem",
            border: "1px solid rgba(239, 68, 68, 0.2)"
          }}>
            {error}
          </div>
        )}

        {success && (
          <div style={{
            padding: "1rem",
            marginBottom: "1.5rem",
            backgroundColor: "var(--accent-emerald-glow)",
            color: "var(--accent-emerald)",
            borderRadius: "8px",
            fontSize: "0.875rem",
            border: "1px solid rgba(16, 185, 129, 0.2)"
          }}>
            {success}
          </div>
        )}

        <form onSubmit={handleRegister} style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
          <div>
            <label style={{ display: "block", marginBottom: "0.5rem", fontSize: "0.875rem", fontWeight: "500", color: "var(--text-primary)" }}>
              Tên hiển thị
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
              style={{
                width: "100%",
                padding: "0.875rem 1rem",
                borderRadius: "8px",
                border: "1px solid var(--border-color)",
                backgroundColor: "var(--bg-obsidian-950)",
                color: "var(--text-primary)",
                outline: "none"
              }}
              placeholder="Ví dụ: Nguyễn Văn A"
            />
          </div>

          <div>
            <label style={{ display: "block", marginBottom: "0.5rem", fontSize: "0.875rem", fontWeight: "500", color: "var(--text-primary)" }}>
              Email
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              style={{
                width: "100%",
                padding: "0.875rem 1rem",
                borderRadius: "8px",
                border: "1px solid var(--border-color)",
                backgroundColor: "var(--bg-obsidian-950)",
                color: "var(--text-primary)",
                outline: "none"
              }}
              placeholder="admin2@spending.local"
            />
          </div>

          <div>
            <label style={{ display: "block", marginBottom: "0.5rem", fontSize: "0.875rem", fontWeight: "500", color: "var(--text-primary)" }}>
              Mật khẩu
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              style={{
                width: "100%",
                padding: "0.875rem 1rem",
                borderRadius: "8px",
                border: "1px solid var(--border-color)",
                backgroundColor: "var(--bg-obsidian-950)",
                color: "var(--text-primary)",
                outline: "none"
              }}
              placeholder="Tối thiểu 8 ký tự"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            style={{
              padding: "1rem",
              borderRadius: "8px",
              backgroundColor: "var(--accent-teal)",
              color: "var(--bg-obsidian-950)",
              fontSize: "1rem",
              fontWeight: "600",
              border: "none",
              cursor: loading ? "not-allowed" : "pointer",
              opacity: loading ? 0.7 : 1,
              marginTop: "0.5rem",
              transition: "background-color 0.2s ease"
            }}
          >
            {loading ? "Đang xử lý..." : "Tạo Tài Khoản"}
          </button>
        </form>
      </div>
    </div>
  );
}

export default RegisterAdminPage;
