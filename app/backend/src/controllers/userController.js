const { createExpense, getExpensesByUser } = require("../models/expenseModel");
const { createAiLog } = require("../models/aiLogModel");
const { createCommentLog } = require("../models/commentLogModel");
const { getCategoryById, getCategoryByName, getAllCategories } = require("../models/categoryModel");
const { getUserById } = require("../models/userModel");
const {
  upsertUserCategoryMapping,
  findMappedCategoryId
} = require("../models/userCategoryMappingModel");
const { extractExpenseFromText, extractExpenseFromBill, chatWithMoneyFriend } = require("../services/aiService");
const { buildEventInsight, buildDailyInsight, buildMonthlyInsight } = require("../services/insightEngineService");
const { generateCommentWithFallback } = require("../services/commentAiService");

function validateImageSize(imageSizeKb) {
  if (imageSizeKb == null) {
    return null;
  }

  const numericSize = Number(imageSizeKb);
  if (!Number.isFinite(numericSize) || numericSize <= 0) {
    return "imageSizeKb must be a positive number";
  }

  if (numericSize > 300) {
    return "Image must be compressed to 300KB or less before upload";
  }

  return null;
}

function formatExpense(expense) {
  const category = getCategoryById(expense.categoryId);

  return {
    ...expense,
    sourceType: expense.type,
    attachmentUrl: expense.imageUrl,
    aiExtracted: Boolean(expense.aiExtracted),
    categoryName: category ? category.name : "Unknown"
  };
}

function resolveCategory({ categoryId, categoryName, fallbackName }) {
  if (categoryId) {
    return getCategoryById(categoryId);
  }

  if (categoryName) {
    return getCategoryByName(categoryName);
  }

  if (fallbackName) {
    return getCategoryByName(fallbackName);
  }

  return getCategoryByName("Other");
}

function getDailyTotalForUser(userId, extraAmount) {
  const now = new Date();
  const dailyExpenses = getExpensesByUser(userId).filter((expense) => {
    const createdDate = new Date(expense.createdAt);
    return (
      createdDate.getUTCFullYear() === now.getUTCFullYear() &&
      createdDate.getUTCMonth() === now.getUTCMonth() &&
      createdDate.getUTCDate() === now.getUTCDate()
    );
  });

  return (
    dailyExpenses.reduce((total, item) => total + Number(item.amount || 0), 0) + Number(extraAmount || 0)
  );
}

async function generateCommentBundle({ userId, persona, insight }) {
  const comment = await generateCommentWithFallback({ persona, insight });

  createCommentLog({
    userId,
    insightData: insight,
    message: comment.message,
    emotion: comment.emotion,
    modelUsed: comment.modelUsed,
    providerUsed: comment.providerUsed
  });

  createAiLog({
    userId,
    flow: "comment",
    provider: comment.providerUsed,
    inputPayload: { insight },
    outputPayload: { message: comment.message, emotion: comment.emotion },
    confidence: 1,
    modelUsed: comment.modelUsed
  });

  return comment;
}

async function postExpense(req, res, next) {
  try {
    const {
      userId = 1,
      flow,
      text,
      storyImageUrl,
      storyThumbnailUrl,
      billImageUrl,
      billThumbnailUrl,
      thumbnailUrl,
      imageSizeKb,
      amount,
      categoryId,
      categoryName,
      note,
      confirm = false,
      persona = "bro"
    } = req.body;

    const user = getUserById(userId);
    if (!user) {
      return res.status(400).json({ message: "Invalid userId" });
    }

    if (!["text", "story", "bill"].includes(flow)) {
      return res.status(400).json({
        message: "flow must be one of: text, story, bill"
      });
    }

    if (flow === "text") {
      if (!text) {
        return res.status(400).json({ message: "text is required for text flow" });
      }

      const nlpResult = extractExpenseFromText(text);
      createAiLog({
        userId,
        flow: "text",
        provider: "nlp",
        inputPayload: { text },
        outputPayload: nlpResult,
        confidence: nlpResult.confidence
      });

      if (!nlpResult.amount) {
        return res.status(422).json({
          message: "Cannot confidently detect amount from text",
          requiresMoreInput: true
        });
      }

      const mappedCategoryId = findMappedCategoryId(userId, text);
      const mappedCategory = mappedCategoryId ? getCategoryById(mappedCategoryId) : null;

      let category = null;
      if (mappedCategory) {
        category = mappedCategory;
      } else if (categoryId || categoryName) {
        category = resolveCategory({ categoryId, categoryName });
        if (category) {
          upsertUserCategoryMapping({ userId, keyword: text, categoryId: category.id });
        }
      } else if (nlpResult.category && nlpResult.category !== "Other") {
        category = resolveCategory({ fallbackName: nlpResult.category });
      }

      if (!category) {
        return res.status(422).json({
          message: "Cannot detect category reliably. Please select category.",
          requiresCategorySelection: true,
          suggestedCategories: getAllCategories().map((item) => ({ id: item.id, name: item.name }))
        });
      }

      const expense = createExpense({
        userId: Number(userId),
        amount: Number(nlpResult.amount),
        categoryId: category.id,
        type: "text",
        aiExtracted: true,
        note: note || text,
        imageUrl: null,
        thumbnailUrl: null,
        status: "saved"
      });

      const eventInsight = buildEventInsight({
        amount: expense.amount,
        categoryName: category.name,
        dailyTotal: getDailyTotalForUser(userId, 0)
      });
      const dailyInsight = buildDailyInsight({
        userExpenses: getExpensesByUser(userId),
        getCategoryById
      });
      const monthlyInsight = buildMonthlyInsight({
        userExpenses: getExpensesByUser(userId),
        getCategoryById,
        monthlyLimit: 5000000
      });
      const comment = await generateCommentBundle({ userId, persona, insight: monthlyInsight });

      return res.status(201).json({
        flow: "text",
        expense: formatExpense(expense),
        ai: nlpResult,
        insight: {
          event: eventInsight,
          daily: dailyInsight,
          monthly: monthlyInsight
        },
        comment: {
          message: comment.message,
          emotion: comment.emotion,
          modelUsed: comment.modelUsed
        }
      });
    }

    if (flow === "story") {
      if (!storyImageUrl || !amount || !(categoryId || categoryName)) {
        return res.status(400).json({
          message: "story flow requires storyImageUrl, amount, and category"
        });
      }

      const imageSizeError = validateImageSize(imageSizeKb);
      if (imageSizeError) {
        return res.status(422).json({ message: imageSizeError });
      }

      const category = resolveCategory({ categoryId, categoryName });
      if (!category) {
        return res.status(400).json({ message: "Invalid category" });
      }

      const finalThumbnailUrl = storyThumbnailUrl || thumbnailUrl || storyImageUrl;

      const expense = createExpense({
        userId: Number(userId),
        amount: Number(amount),
        categoryId: category.id,
        type: "story",
        aiExtracted: false,
        note: note || "Story expense",
        imageUrl: storyImageUrl,
        thumbnailUrl: finalThumbnailUrl,
        status: "saved"
      });

      const eventInsight = buildEventInsight({
        amount: expense.amount,
        categoryName: category.name,
        dailyTotal: getDailyTotalForUser(userId, 0)
      });
      const monthlyInsight = buildMonthlyInsight({
        userExpenses: getExpensesByUser(userId),
        getCategoryById,
        monthlyLimit: 5000000
      });
      const comment = await generateCommentBundle({ userId, persona, insight: monthlyInsight });

      return res.status(201).json({
        flow: "story",
        expense: formatExpense(expense),
        ai: null,
        insight: { event: eventInsight, monthly: monthlyInsight },
        comment: {
          message: comment.message,
          emotion: comment.emotion,
          modelUsed: comment.modelUsed
        },
        message: "Story flow does not call AI. Saved with user-provided amount and category."
      });
    }

    if (!billImageUrl) {
      return res.status(400).json({ message: "billImageUrl is required for bill flow" });
    }

    const imageSizeError = validateImageSize(imageSizeKb);
    if (imageSizeError) {
      return res.status(422).json({ message: imageSizeError });
    }

    const visionResult = extractExpenseFromBill(billImageUrl);
    createAiLog({
      userId,
      flow: "bill",
      provider: "vision",
      inputPayload: { billImageUrl },
      outputPayload: visionResult,
      confidence: visionResult.confidence
    });

    if (!confirm) {
      return res.status(200).json({
        flow: "bill",
        requiresConfirmation: true,
        suggestion: {
          amount: visionResult.amount,
          category: visionResult.suggestedCategory,
          confidence: visionResult.confidence
        },
        message:
          visionResult.confidence < 0.8 || !visionResult.amount
            ? "OCR confidence is low. Please enter amount manually before saving."
            : "Please confirm or edit amount/category before saving."
      });
    }

    const finalAmount = Number(amount || visionResult.amount);
    if (!Number.isFinite(finalAmount) || finalAmount <= 0) {
      return res.status(422).json({
        message: "Amount is required when bill OCR confidence is low or missing"
      });
    }

    const category = resolveCategory({
      categoryId,
      categoryName,
      fallbackName: visionResult.suggestedCategory
    });

    const finalThumbnailUrl = billThumbnailUrl || thumbnailUrl || billImageUrl;

    const expense = createExpense({
      userId: Number(userId),
      amount: finalAmount,
      categoryId: category.id,
      type: "bill",
      aiExtracted: true,
      note: note || "Bill scan",
      imageUrl: billImageUrl,
      thumbnailUrl: finalThumbnailUrl,
      status: "saved"
    });

    const eventInsight = buildEventInsight({
      amount: expense.amount,
      categoryName: category.name,
      dailyTotal: getDailyTotalForUser(userId, 0)
    });
    const monthlyInsight = buildMonthlyInsight({
      userExpenses: getExpensesByUser(userId),
      getCategoryById,
      monthlyLimit: 5000000
    });
    const comment = await generateCommentBundle({ userId, persona, insight: monthlyInsight });

    return res.status(201).json({
      flow: "bill",
      confirmed: true,
      expense: formatExpense(expense),
      ai: visionResult,
      insight: { event: eventInsight, monthly: monthlyInsight },
      comment: {
        message: comment.message,
        emotion: comment.emotion,
        modelUsed: comment.modelUsed
      }
    });
  } catch (error) {
    return next(error);
  }
}

async function getUserExpenses(req, res, next) {
  try {
    const userId = req.query.userId;
    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    const user = getUserById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const expenses = getExpensesByUser(userId).map(formatExpense);

    return res.status(200).json({
      count: expenses.length,
      expenses
    });
  } catch (error) {
    return next(error);
  }
}

async function postUserChat(req, res, next) {
  try {
    const { userId = 1, message, context, persona = "bro" } = req.body;

    if (!message) {
      return res.status(400).json({ message: "message is required" });
    }

    const reply = chatWithMoneyFriend(message, context);
    const syntheticInsight = {
      type: "event",
      top_category: context?.topCategory || "chi tieu",
      percent: Number(context?.percent || 0),
      change: Number(context?.change || 0),
      exceed_limit: Boolean(context?.exceed_limit)
    };
    const comment = await generateCommentBundle({
      userId,
      persona,
      insight: syntheticInsight
    });

    createAiLog({
      userId,
      flow: "chat",
      provider: "llm",
      inputPayload: { message, context: context || {} },
      outputPayload: { reply },
      confidence: 1
    });

    return res.status(200).json({
      reply,
      comment: {
        message: comment.message,
        emotion: comment.emotion,
        modelUsed: comment.modelUsed
      }
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  postExpense,
  getUserExpenses,
  postUserChat
};
