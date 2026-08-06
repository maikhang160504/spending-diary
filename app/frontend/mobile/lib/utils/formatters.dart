import 'package:flutter/services.dart';

int parseToInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  if (val is num) return val.toInt();
  if (val is String) {
    final cleaned = val.trim();
    final parsedDouble = double.tryParse(cleaned);
    if (parsedDouble != null) return parsedDouble.toInt();
    final parsedInt = int.tryParse(cleaned);
    if (parsedInt != null) return parsedInt;
  }
  return 0;
}

double parseToDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is double) return val;
  if (val is int) return val.toDouble();
  if (val is num) return val.toDouble();
  if (val is String) {
    final cleaned = val.trim();
    final parsedDouble = double.tryParse(cleaned);
    if (parsedDouble != null) return parsedDouble;
  }
  return 0.0;
}

String formatVnd(int value) {
  final isNegative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    final indexFromEnd = digits.length - 1 - i;
    buffer.write(digits[indexFromEnd]);
    if ((i + 1) % 3 == 0 && i + 1 < digits.length) {
      buffer.write('.');
    }
  }

  final formatted = buffer.toString().split('').reversed.join();
  return '${isNegative ? '-' : ''}$formatted đ';
}

/// Compact formatter: 1.5Tr, 250K, etc. for donut chart center label
String formatVndCompact(int value) {
  final isNegative = value < 0;
  final abs = value.abs();
  String result;
  if (abs >= 1000000000) {
    result = '${(abs / 1000000000).toStringAsFixed(1)}Tỷ';
  } else if (abs >= 1000000) {
    final tr = abs / 1000000;
    result = tr >= 10
        ? '${tr.toStringAsFixed(0)}Tr'
        : '${tr.toStringAsFixed(1)}Tr';
  } else if (abs >= 1000) {
    result = '${(abs / 1000).toStringAsFixed(0)}K';
  } else {
    result = '$abs';
  }
  return '${isNegative ? '-' : ''}$result đ';
}

/// ISO timestamp for sort/display: prefer occurred_at over created_at.
String? txTimestampIso(Map<String, dynamic> tx) {
  for (final key in ['occurredAt', 'occurred_at', 'createdAt', 'created_at']) {
    final v = tx[key];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  return null;
}

DateTime? parseToLocalDateTime(dynamic iso) {
  if (iso == null) return null;
  final s = iso.toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return null;
  }
}

/// Date-only values (YYYY-MM-DD) borrow clock time from [timeSourceIso].
DateTime? parseStoryDisplayDateTime(dynamic iso, {dynamic timeSourceIso}) {
  final s = iso?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  try {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      final date = DateTime.parse(s).toLocal();
      final src = parseToLocalDateTime(timeSourceIso);
      if (src != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          src.hour,
          src.minute,
          src.second,
        );
      }
      return DateTime(date.year, date.month, date.day, 12, 0);
    }
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return null;
  }
}

String formatDateTimeShort(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}';

String formatDateTimeFull(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';

String formatTimeOnly(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

int compareByTimestampDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
  final da = parseToLocalDateTime(txTimestampIso(a));
  final db = parseToLocalDateTime(txTimestampIso(b));
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return db.compareTo(da);
}

String? storyTimestampIso(Map<String, dynamic> story) {
  for (final key in ['latest_occurred_at', 'latestOccurredAt']) {
    final v = story[key];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  for (final key in ['created_at', 'createdAt', 'occurred_on', 'occurredOn']) {
    final v = story[key];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  return null;
}

int compareStoryByTimestampDesc(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final da = parseToLocalDateTime(storyTimestampIso(a));
  final db = parseToLocalDateTime(storyTimestampIso(b));
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return db.compareTo(da);
}

/// Best display timestamp for story detail header (includes minutes when possible).
String? resolveStoryDisplayIso(Map<String, dynamic> story) {
  final items = story['items'] as List<dynamic>?;
  if (items != null) {
    DateTime? best;
    String? bestIso;
    for (final item in items) {
      if (item is! Map) continue;
      final txs = item['transactions'] as List<dynamic>?;
      if (txs == null) continue;
      for (final tx in txs) {
        if (tx is! Map) continue;
        final iso = txTimestampIso(Map<String, dynamic>.from(tx));
        final dt = parseToLocalDateTime(iso);
        if (dt != null && (best == null || dt.isAfter(best))) {
          best = dt;
          bestIso = iso;
        }
      }
    }
    if (bestIso != null) return bestIso;
  }

  final latest = story['latest_occurred_at'] ?? story['latestOccurredAt'];
  if (latest != null && latest.toString().trim().isNotEmpty) {
    return latest.toString();
  }

  final created = story['created_at'] ?? story['createdAt'];
  final occurredOn = story['occurred_on'] ?? story['occurredOn'];
  if (occurredOn != null && occurredOn.toString().trim().isNotEmpty) {
    final dt = parseStoryDisplayDateTime(occurredOn, timeSourceIso: created);
    return dt?.toIso8601String();
  }

  return storyTimestampIso(story);
}

/// Parses a user-entered money string (may contain commas or dots as separators)
/// back to a double. E.g. "2,000,000" → 2000000.0
double? parseMoneyInput(String raw) {
  final cleaned = raw
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .replaceAll('đ', '')
      .trim();
  return double.tryParse(cleaned);
}

/// Formats number with comma thousands separator while typing (no currency symbol).
/// E.g. user types 2000000 → shows "2,000,000"
class MoneyTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip all non-digit characters
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    // Add commas every 3 digits from right
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - 1 - i;
      buffer.write(digits[indexFromEnd]);
      if ((i + 1) % 3 == 0 && i + 1 < digits.length) {
        buffer.write(',');
      }
    }
    final formatted = buffer.toString().split('').reversed.join();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
