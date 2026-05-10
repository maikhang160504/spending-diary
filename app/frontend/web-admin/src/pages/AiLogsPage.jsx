import { useEffect, useState } from "react";
import { getAdminAiLogs } from "../services/api";

function AiLogsPage() {
  const [logs, setLogs] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    getAdminAiLogs()
      .then((payload) => setLogs(payload.logs || []))
      .catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <h1>Xem log AI</h1>
      {error && <p className="error">{error}</p>}
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Flow</th>
            <th>Provider</th>
            <th>Confidence</th>
            <th>Created</th>
          </tr>
        </thead>
        <tbody>
          {logs.map((log) => (
            <tr key={log.id}>
              <td>{log.id}</td>
              <td>{log.flow}</td>
              <td>{log.provider}</td>
              <td>{log.confidence}</td>
              <td>{new Date(log.createdAt).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

export default AiLogsPage;
