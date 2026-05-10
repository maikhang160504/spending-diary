const ALLOWED_EMOTIONS = [
  "base",
  "happy",
  "cry",
  "chill",
  "rich",
  "wallet",
  "angry",
  "shock",
  "sleepy"
];

function chooseEmotionByRule(insight) {
  if (insight.exceed_limit) {
    return "angry";
  }
  if (Number(insight.change || 0) > 20) {
    return "shock";
  }
  if (Number(insight.percent || 0) < 20) {
    return "happy";
  }
  return "chill";
}

function buildMessageFromInsight(insight, persona) {
  const vibe = persona === "bestie" ? "bestie" : "bro";
  const category = insight.top_category || insight.category || "chi tieu";

  if (insight.type === "monthly") {
    if (insight.exceed_limit) {
      return vibe === "bestie"
        ? `Thang nay ban dang vuot gioi han roi nha. Top chi tieu la ${category} (${insight.percent}%). Minh giam nhe 1 chut de can bang lai nhe.`
        : `Thang nay ban dang vuot limit. ${category} chiem ${insight.percent}%, minh cat bot khoan nay truoc nha.`;
    }

    return vibe === "bestie"
      ? `Thang nay top chi la ${category} (${insight.percent}%). Minh giu phong do nay la dep do nha.`
      : `Top muc chi thang nay la ${category} (${insight.percent}%). Nhin chung dang on.`;
  }

  return vibe === "bestie"
    ? `Minh da ghi nhan giao dich ${insight.amount} cho ${category}. Minh theo doi tiep de giup ban can doi ne.`
    : `Da ghi ${insight.amount} cho ${category}. Minh tiep tuc canh giup ban.`;
}

function mockProviderCall(provider, payload) {
  const message = buildMessageFromInsight(payload.insight, payload.persona);
  return {
    provider,
    modelUsed:
      provider === "gemini"
        ? "gemini-1.5-flash"
        : provider === "openai"
          ? "gpt-4.1-mini"
          : "openrouter/auto",
    message,
    emotion: chooseEmotionByRule(payload.insight)
  };
}

function enforceAllowedEmotion(emotion) {
  if (ALLOWED_EMOTIONS.includes(emotion)) {
    return emotion;
  }
  return "base";
}

async function generateCommentWithFallback({ persona = "bro", insight }) {
  const providers = ["gemini", "openai", "openrouter"];
  let lastError = null;

  for (const provider of providers) {
    try {
      const result = mockProviderCall(provider, { persona, insight });
      const emotionFromRule = chooseEmotionByRule(insight);
      const safeEmotion = enforceAllowedEmotion(emotionFromRule || result.emotion);

      return {
        message: result.message,
        emotion: safeEmotion,
        modelUsed: result.modelUsed,
        providerUsed: provider
      };
    } catch (error) {
      lastError = error;
    }
  }

  return {
    message: "Minh da nhan du lieu chi tieu. Hien tai AI gap loi, ban thu lai sau nhe.",
    emotion: "base",
    modelUsed: "fallback-rule",
    providerUsed: "none",
    error: lastError ? String(lastError.message || lastError) : "unknown"
  };
}

module.exports = {
  ALLOWED_EMOTIONS,
  chooseEmotionByRule,
  generateCommentWithFallback
};
