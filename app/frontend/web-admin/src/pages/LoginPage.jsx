import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { loginAdmin } from "../services/api";

function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");

    // Frontend validation
    const trimmedEmail = email.trim();
    const trimmedPass = password.trim();
    if (!trimmedEmail) { setError("Vui lòng nhập email"); return; }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) { setError("Email không đúng định dạng"); return; }
    if (!trimmedPass) { setError("Vui lòng nhập mật khẩu"); return; }
    if (trimmedPass.length < 6) { setError("Mật khẩu tối thiểu 6 ký tự"); return; }

    setLoading(true);
    try {
      await loginAdmin(trimmedEmail, password);
      navigate("/");
    } catch (err) {
      setError(err.message || "Đăng nhập thất bại");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      display: "flex",
      minHeight: "100vh",
      backgroundColor: "var(--bg-obsidian-950)",
      fontFamily: "var(--font-sans)",
      color: "var(--text-primary)"
    }}>
      {/* Left side: Branding / Visual */}
      <div style={{
        flex: 1,
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        padding: "4rem",
        background: "linear-gradient(135deg, var(--bg-obsidian-900) 0%, var(--bg-obsidian-950) 100%)",
        borderRight: "1px solid var(--border-color)",
        position: "relative",
        overflow: "hidden"
      }}>
        {/* Subtle glowing orb for premium feel */}
        <div style={{
          position: "absolute",
          top: "30%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          width: "40vw",
          height: "40vw",
          background: "radial-gradient(circle, rgba(20,184,166,0.1) 0%, rgba(20,184,166,0) 70%)",
          borderRadius: "50%",
          pointerEvents: "none",
          zIndex: 0
        }} />
        
        <div style={{ zIndex: 1, textAlign: "center", maxWidth: "480px" }}>
          <div style={{ 
            display: "inline-flex", 
            alignItems: "center", 
            justifyContent: "center",
            width: "64px",
            height: "64px",
            borderRadius: "16px",
            background: "var(--accent-teal-glow)",
            border: "1px solid rgba(20, 184, 166, 0.2)",
            marginBottom: "2rem"
          }}>
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--accent-teal)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
          </div>
          <h1 style={{ fontSize: "2.5rem", fontWeight: "700", letterSpacing: "-0.02em", marginBottom: "1rem" }}>
            Spending <span style={{ color: "var(--accent-teal)" }}>Admin</span>
          </h1>
          <p style={{ fontSize: "1.125rem", color: "var(--text-secondary)", lineHeight: "1.6" }}>
            Hệ thống quản trị tài chính thông minh, tích hợp AI để tối ưu hóa việc phân tích và đánh giá dữ liệu hóa đơn, văn bản.
          </p>
        </div>
      </div>

      {/* Right side: Login Form */}
      <div style={{
        flex: 1,
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        padding: "4rem",
        backgroundColor: "var(--bg-obsidian-950)"
      }}>
        <div style={{
          width: "100%",
          maxWidth: "400px",
        }}>
          <div style={{ marginBottom: "2.5rem" }}>
            <h2 style={{ fontSize: "1.875rem", fontWeight: "600", color: "var(--text-primary)", marginBottom: "0.5rem" }}>
              Đăng nhập Cockpit
            </h2>
            <p style={{ color: "var(--text-secondary)" }}>
              Vui lòng nhập thông tin xác thực quản trị viên
            </p>
          </div>

          {error && (
            <div style={{
              padding: "1rem",
              marginBottom: "1.5rem",
              backgroundColor: "var(--accent-rose-glow)",
              color: "var(--accent-rose)",
              borderRadius: "8px",
              fontSize: "0.875rem",
              border: "1px solid rgba(239, 68, 68, 0.2)",
              display: "flex",
              alignItems: "center",
              gap: "0.5rem"
            }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="8" x2="12" y2="12"></line>
                <line x1="12" y1="16" x2="12.01" y2="16"></line>
              </svg>
              {error}
            </div>
          )}

          <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
            <div>
              <label style={{ display: "block", marginBottom: "0.5rem", fontSize: "0.875rem", fontWeight: "500", color: "var(--text-primary)" }}>
                Email / Tài khoản
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
                  backgroundColor: "var(--bg-obsidian-900)",
                  color: "var(--text-primary)",
                  fontSize: "1rem",
                  outline: "none",
                  transition: "all 0.2s ease"
                }}
                onFocus={(e) => e.target.style.borderColor = "var(--accent-teal)"}
                onBlur={(e) => e.target.style.borderColor = "var(--border-color)"}
                placeholder="admin@spending.local"
              />
            </div>

            <div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.5rem" }}>
                <label style={{ fontSize: "0.875rem", fontWeight: "500", color: "var(--text-primary)" }}>
                  Mật khẩu
                </label>
              </div>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{
                  width: "100%",
                  padding: "0.875rem 1rem",
                  borderRadius: "8px",
                  border: "1px solid var(--border-color)",
                  backgroundColor: "var(--bg-obsidian-900)",
                  color: "var(--text-primary)",
                  fontSize: "1rem",
                  outline: "none",
                  transition: "all 0.2s ease"
                }}
                onFocus={(e) => e.target.style.borderColor = "var(--accent-teal)"}
                onBlur={(e) => e.target.style.borderColor = "var(--border-color)"}
                placeholder="••••••••"
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
                transition: "background-color 0.2s ease",
                display: "flex",
                justifyContent: "center",
                alignItems: "center",
                gap: "0.5rem"
              }}
              onMouseEnter={(e) => { if(!loading) e.target.style.backgroundColor = "var(--accent-teal-hover)" }}
              onMouseLeave={(e) => { if(!loading) e.target.style.backgroundColor = "var(--accent-teal)" }}
            >
              {loading ? (
                <>
                  <svg className="animate-spin" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ animation: "spin 1s linear infinite" }}>
                    <path d="M21 12a9 9 0 1 1-6.219-8.56" />
                  </svg>
                  Đang xác thực...
                </>
              ) : (
                "Đăng nhập hệ thống"
              )}
            </button>
          </form>
          
          <style dangerouslySetInnerHTML={{__html: `
            @keyframes spin {
              from { transform: rotate(0deg); }
              to { transform: rotate(360deg); }
            }
          `}} />
        </div>
      </div>
    </div>
  );
}

export default LoginPage;
