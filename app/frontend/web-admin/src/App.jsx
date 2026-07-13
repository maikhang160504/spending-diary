import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import DashboardPage from "./pages/DashboardPage";
import NluOpsPage from "./pages/NluOpsPage";
import UserManagementPage from "./pages/UserManagementPage";
import BotPromptsPage from "./pages/BotPromptsPage";
import BillRetrainPage from "./pages/BillRetrainPage";
import MonetizationPage from "./pages/MonetizationPage";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<DashboardPage />} />
          <Route path="nlu-ops" element={<NluOpsPage />} />
          <Route path="users" element={<UserManagementPage />} />
          <Route path="user-inspector" element={<Navigate to="/users" replace />} />
          <Route path="bill-retrain" element={<BillRetrainPage />} />
          <Route path="bot-prompts" element={<BotPromptsPage />} />
          <Route path="monetization" element={<MonetizationPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
