import 'package:flutter/foundation.dart';

import 'nlu_parse.dart';

/// Đồng bộ với expense-ocr-nlu/src/nlg/mimo_assets.py
const kMimoAssetNames = {
  'Alert', 'Angry', 'Approved', 'Celebrate', 'Chill', 'Cooking', 'Cool',
  'Determined', 'Error', 'Excited', 'Giggle', 'Happy', 'Hello', 'Loading',
  'Love', 'Proud', 'Relax', 'Sad', 'Sleepy', 'Sassy', 'Shopping', 'Travel',
  'Sorry', 'Success', 'Taunting', 'Thankful', 'Thinking', 'Working', 'Worried',
};

const _nlgPersonaKeys = {
  'hai_huoc', 'dan_doi', 'dong_cam', 'cham_choc', 'nghiem_tuc', 'vui',
};

String normalizeVerbalStyle(String? raw) => raw == 'strict' ? 'strict' : 'funny';

String personalityLabelFromStyle(String verbalStyle) =>
    verbalStyle == 'strict' ? 'Dận Dữ' : 'Dui Dẻ';

String personalityMascotAsset(String verbalStyle) =>
    verbalStyle == 'strict'
        ? 'assets/MiMo/emotions/Angry.png'
        : 'assets/MiMo/emotions/Cool.png';

String personalityNlgPersona(String verbalStyle) =>
    verbalStyle == 'strict' ? 'dan_doi' : 'hai_huoc';

/// Trả về tên PNG nếu LLM chọn hợp lệ; null nếu không.
String? coerceMimoAssetName(String? value) {
  if (value == null || value.isEmpty) return null;
  final trimmed = value.trim();
  if (_nlgPersonaKeys.contains(trimmed)) return null;
  if (kMimoAssetNames.contains(trimmed)) return trimmed;
  for (final name in kMimoAssetNames) {
    if (name.toLowerCase() == trimmed.toLowerCase()) return name;
  }
  return null;
}

/// Alias tiện cho feed/history — vẫn ưu tiên đúng tên LLM.
String normalizeMimoAssetName(String? value, {String fallback = 'Hello'}) =>
    coerceMimoAssetName(value) ?? fallback;

class LlmMimoReply {
  final String text;
  final String emotionAsset;

  const LlmMimoReply({required this.text, required this.emotionAsset});

  factory LlmMimoReply.fromNlu(
    Map<String, dynamic> nlu, {
    String? intent,
    bool logEmotion = true,
  }) {
    final i = intent ?? nluString(nlu['intent']) ?? 'Chitchat';
    final emotionAsset = resolveMimoEmotionAsset(nlu, intent: i);
    if (logEmotion) {
      _debugLogMimoEmotion(nlu, intent: i, resolved: emotionAsset);
    }
    return LlmMimoReply(
      text: resolveLlmReplyText(nlu) ?? nluString(nlu['nlg_response']) ?? '',
      emotionAsset: emotionAsset,
    );
  }

  static String intentEmotionFallback(String intent) =>
      intent == 'Record' ? 'Success' : (intent == 'Action' ? 'Approved' : 'Hello');

  Map<String, dynamic> toStoryPersistFields() => {
        'mascotMood': emotionAsset,
        if (text.isNotEmpty) 'aiComment': text,
      };

  String get emotionAssetPath => 'assets/MiMo/emotions/$emotionAsset.png';
}

void _debugLogMimoEmotion(
  Map<String, dynamic> nlu, {
  required String intent,
  required String resolved,
}) {
  if (!kDebugMode) return;

  final gemini = nluMap(nlu['gemini_json']);
  final llama = nluMap(nlu['llama_json']);
  final fields = <String, String?>{
    'mimo_emotion': nluString(nlu['mimo_emotion']),
    'llm_emotion': nluString(nlu['llm_emotion']),
    'mascot_mood': nluString(nlu['mascot_mood']),
    'gemini_json.mimo_emotion': nluString(gemini?['mimo_emotion']),
    'gemini_json.emotion': nluString(gemini?['emotion']),
    'llama_json.mimo_emotion': nluString(llama?['mimo_emotion']),
    'llama_json.emotion': nluString(llama?['emotion']),
  };

  String? pickedField;
  String? pickedRaw;
  for (final entry in fields.entries) {
    if (entry.value == null || entry.value!.isEmpty) continue;
    if (coerceMimoAssetName(entry.value) == resolved) {
      pickedField = entry.key;
      pickedRaw = entry.value;
      break;
    }
  }

  final fallback = LlmMimoReply.intentEmotionFallback(intent);
  final fromLlm = pickedField != null;
  debugPrint(
    '[mimo-emotion] intent=$intent → $resolved '
    '(${fromLlm ? 'LLM' : 'fallback=$fallback'})',
  );
  if (fromLlm) {
    debugPrint('[mimo-emotion]   nguồn: $pickedField = $pickedRaw');
  } else {
    debugPrint('[mimo-emotion]   raw từ API: $fields');
    if (gemini != null && gemini.containsKey('status') && !gemini.containsKey('mimo_emotion')) {
      debugPrint(
        '[mimo-emotion]   ⚠ gemini_json cũ (story/status) — restart AI service sau khi cập nhật schema',
      );
    }
  }
  debugPrint('[mimo-emotion]   asset: assets/MiMo/emotions/$resolved.png');
}

/// Đọc mimo_emotion LLM đã chọn → tên file PNG (không suy từ status).
String resolveMimoEmotionAsset(Map<String, dynamic> nlu, {String? intent}) {
  final i = intent ?? nluString(nlu['intent']) ?? 'Chitchat';
  final gemini = nluMap(nlu['gemini_json']);
  final llama = nluMap(nlu['llama_json']);

  for (final raw in [
    nluString(nlu['mimo_emotion']),
    nluString(nlu['llm_emotion']),
    nluString(nlu['mascot_mood']),
    nluString(gemini?['mimo_emotion']),
    nluString(gemini?['emotion']),
    nluString(llama?['mimo_emotion']),
    nluString(llama?['emotion']),
  ]) {
    final asset = coerceMimoAssetName(raw);
    if (asset != null) return asset;
  }

  return LlmMimoReply.intentEmotionFallback(i);
}

/// Cùng thứ tự ưu tiên với BE `transactions.service` (response trước story).
String? resolveLlmReplyText(Map<String, dynamic> nlu) {
  final gemini = nluMap(nlu['gemini_json']);
  final llama = nluMap(nlu['llama_json']);
  return nluString(gemini?['response'])
      ?? nluString(gemini?['story'])
      ?? nluString(llama?['response'])
      ?? nluString(llama?['story'])
      ?? nluString(nlu['nlg_response'])
      ?? nluString(nlu['response']);
}

/// Một nguồn text cho bubble chat, lưu session và ai_comment story.
String canonicalAiReplyText(LlmMimoReply llm, {String? displayFallback}) {
  final raw = llm.text.trim();
  if (raw.isNotEmpty) return raw;
  return (displayFallback ?? '').trim();
}

LlmMimoReply? llmReplyFromChatMetadata(Map<String, dynamic>? metadata, {String? fallbackText}) {
  if (metadata == null) return null;
  final nlu = nluMap(metadata['nlu']);
  if (nlu != null) {
    final fromNlu = LlmMimoReply.fromNlu(
      nlu,
      intent: nluString(metadata['intent']),
      logEmotion: false,
    );
    final stored = nluString(metadata['aiComment']) ?? nluString(metadata['story']);
    if (stored != null && stored.isNotEmpty) {
      return LlmMimoReply(text: stored, emotionAsset: fromNlu.emotionAsset);
    }
    return fromNlu;
  }
  final mood = nluString(metadata['mood']);
  final text = fallbackText ?? '';
  if (mood == null && text.isEmpty) return null;
  final intent = nluString(metadata['intent']) ?? 'Chitchat';
  return LlmMimoReply(
    text: text,
    emotionAsset: coerceMimoAssetName(mood) ?? LlmMimoReply.intentEmotionFallback(intent),
  );
}
