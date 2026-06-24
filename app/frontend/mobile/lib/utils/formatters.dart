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

/// Parses a user-entered money string (may contain commas or dots as separators)
/// back to a double. E.g. "2,000,000" → 2000000.0
double? parseMoneyInput(String raw) {
  final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').replaceAll('đ', '').trim();
  return double.tryParse(cleaned);
}

/// Formats number with comma thousands separator while typing (no currency symbol).
/// E.g. user types 2000000 → shows "2,000,000"
class MoneyTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
