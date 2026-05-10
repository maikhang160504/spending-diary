const express = require("express");
const { postExpense, getUserExpenses, postUserChat } = require("../controllers/userController");

const router = express.Router();

router.post("/expense", postExpense);
router.get("/expenses", getUserExpenses);
router.post("/chat", postUserChat);

module.exports = router;
