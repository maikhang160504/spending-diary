import { useEffect, useState } from "react";
import { getAdminUsers } from "../services/api";

function UsersPage() {
  const [users, setUsers] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    getAdminUsers()
      .then((payload) => setUsers(payload.users || []))
      .catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <h1>Quan ly user</h1>
      {error && <p className="error">{error}</p>}
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Role</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id}>
              <td>{user.id}</td>
              <td>{user.name}</td>
              <td>{user.email}</td>
              <td>{user.role}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

export default UsersPage;
