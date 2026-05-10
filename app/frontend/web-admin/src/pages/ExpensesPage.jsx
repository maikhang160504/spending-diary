import { useEffect, useState } from "react";
import { getUserExpenses } from "../services/api";

function ExpensesPage() {
  const [expenses, setExpenses] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    getUserExpenses()
      .then((payload) => setExpenses(payload.expenses || []))
      .catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <h1>Xem chi tieu</h1>
      {error && <p className="error">{error}</p>}
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Amount</th>
            <th>Category</th>
            <th>Flow</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {expenses.map((expense) => (
            <tr key={expense.id}>
              <td>{expense.id}</td>
              <td>{Number(expense.amount).toLocaleString()} VND</td>
              <td>{expense.categoryName}</td>
              <td>{expense.type || expense.sourceType}</td>
              <td>{expense.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

export default ExpensesPage;
