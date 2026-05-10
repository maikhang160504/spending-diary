const express = require("express");
const { getAdminUsers, getAdminAnalytics, getAdminAiLogs } = require("../controllers/adminController");

const router = express.Router();

router.get("/users", getAdminUsers);
router.get("/analytics", getAdminAnalytics);
router.get("/ai-logs", getAdminAiLogs);

module.exports = router;
