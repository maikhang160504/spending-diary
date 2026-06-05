/// Giờ Việt Nam (UTC+7) — parse ISO server (UTC) và hiển thị local VN.
class VnTime {
  static const _offset = Duration(hours: 7);

  static DateTime now() => DateTime.now().toUtc().add(_offset);

  static DateTime fromIso(String iso) {
    final parsed = DateTime.parse(iso);
    final utc = parsed.isUtc ? parsed : parsed.toUtc();
    return utc.add(_offset);
  }

  static String formatHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String formatHmNow() => formatHm(now());

  static String formatHmFromIso(String? iso) {
    if (iso == null || iso.isEmpty) return formatHmNow();
    try {
      return formatHm(fromIso(iso));
    } catch (_) {
      return formatHmNow();
    }
  }
}
