import { useMemo, useEffect, useState } from "react";
import { getUserExpenses } from "../services/api";

function CategoriesPage() {
  const [expenses, setExpenses] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    getUserExpenses()
      .then((payload) => setExpenses(payload.expenses || []))
      .catch((err) => setError(err.message));
  }, []);

  const categories = useMemo(() => {
    const bucket = new Map();

    expenses.forEach((expense) => {
      const name = expense.categoryName || "Unknown";
      const current = bucket.get(name) || { count: 0, total: 0 };
      bucket.set(name, {
        count: current.count + 1,
        total: current.total + Number(expense.amount || 0)
      });
    });

    return Array.from(bucket.entries()).map(([name, value]) => ({
      name,
      ...value
    }));
  }, [expenses]);

  return (
    <section>
      <h1>Quan ly danh muc</h1>
      {error && <p className="error">{error}</p>}
      <table>
        <thead>
          <tr>
            <th>Category</th>
            <th>Transactions</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody>
          {categories.map((category) => (
            <tr key={category.name}>
              <td>{category.name}</td>
              <td>{category.count}</td>
              <td>{Number(category.total).toLocaleString()} VND</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

export default CategoriesPage;
