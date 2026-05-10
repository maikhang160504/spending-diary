import { useEffect, useState } from "react";
import { getAdminAnalytics } from "../services/api";

function DashboardPage() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    getAdminAnalytics().then(setData).catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <h1>Dashboard</h1>
      {error && <p className="error">{error}</p>}
      {!data && !error && <p>Dang tai du lieu...</p>}
      {data && (
        <div className="grid">
          <article className="card">
            <h3>Total users</h3>
            <p>{data.totalUsers}</p>
          </article>
          <article className="card">
            <h3>Total expenses</h3>
            <p>{data.totalExpenses}</p>
          </article>
          <article className="card">
            <h3>Total expense amount</h3>
            <p>{Number(data.totalExpenseAmount).toLocaleString()} VND</p>
          </article>
        </div>
      )}
    </section>
  );
}

export default DashboardPage;
