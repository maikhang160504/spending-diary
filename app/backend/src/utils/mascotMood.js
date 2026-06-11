'use strict';

/** Đồng bộ với expense-ocr-nlu/src/nlg/mimo_assets.py MIMO_ASSET_NAMES */
const MIMO_ASSET_NAMES = new Set([
  'Alert', 'Angry', 'Approved', 'Celebrate', 'Chill', 'Cooking', 'Cool',
  'Determined', 'Error', 'Excited', 'Giggle', 'Happy', 'Hello', 'Loading',
  'Love', 'Proud', 'Relax', 'Sad', 'Sleepy', 'Sassy', 'Shopping', 'Travel',
  'Sorry', 'Success', 'Taunting', 'Thankful', 'Thinking', 'Working', 'Worried',
]);

const NLG_PERSONA_KEYS = new Set(['hai_huoc', 'dan_doi', 'dong_cam', 'cham_choc', 'nghiem_tuc', 'vui']);

function intentFallback(intent) {
  if (intent === 'Record') return 'Success';
  if (intent === 'Action') return 'Approved';
  return 'Hello';
}

/** Chuẩn hóa nhẹ; null nếu không phải tên LLM hợp lệ. */
function coerceMimoAsset(raw) {
  if (raw == null || String(raw).trim() === '') return null;
  const trimmed = String(raw).trim();
  const lower = trimmed.toLowerCase();

  const PERSONA_TO_EMOTION = {
    vui: 'Happy',
    dan_doi: 'Worried',
    cham_choc: 'Taunting',
    dong_cam: 'Chill',
    nghiem_tuc: 'Approved',
    hai_huoc: 'Giggle',
  };
  if (PERSONA_TO_EMOTION[lower]) {
    return PERSONA_TO_EMOTION[lower];
  }

  if (NLG_PERSONA_KEYS.has(trimmed)) return null;
  if (MIMO_ASSET_NAMES.has(trimmed)) return trimmed;
  for (const name of MIMO_ASSET_NAMES) {
    if (name.toLowerCase() === trimmed.toLowerCase()) return name;
  }
  return null;
}

/** Lấy đúng mimo_emotion LLM đã chọn — không suy từ status. */
function pickMimoEmotionFromNlu(nlu, intent = 'Chitchat') {
  if (!nlu || typeof nlu !== 'object') return intentFallback(intent);

  const candidates = [
    nlu.mimo_emotion,
    nlu.llm_emotion,
    nlu.mascot_mood,
    nlu.gemini_json?.mimo_emotion,
    nlu.gemini_json?.emotion,
    nlu.llama_json?.mimo_emotion,
    nlu.llama_json?.emotion,
  ];

  for (const raw of candidates) {
    const asset = coerceMimoAsset(raw);
    if (asset) return asset;
  }

  return intentFallback(intent);
}

function normalizeMascotMood(raw, intent = 'Chitchat') {
  return coerceMimoAsset(raw) || intentFallback(intent);
}

module.exports = { normalizeMascotMood, pickMimoEmotionFromNlu, intentFallback, MIMO_ASSET_NAMES };
