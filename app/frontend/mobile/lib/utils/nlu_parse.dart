/// Helpers parse NLU JSON an toàn (tránh TypeError → "Mimo gặp lỗi").
Map<String, dynamic>? nluMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

String? nluString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

int? nluInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? nluDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
