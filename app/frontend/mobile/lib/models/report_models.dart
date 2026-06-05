class ReportBar {
  final String label;
  final int amount;

  const ReportBar({required this.label, required this.amount});
}

class ReportCategory {
  final String code;
  final String label;
  final String emoji;
  final double percent;
  final int amount;
  final int color;

  const ReportCategory({
    this.code = 'Other',
    required this.label,
    required this.emoji,
    required this.percent,
    required this.amount,
    required this.color,
  });
}

class TrendPoint {
  final String label;
  final int amount;

  const TrendPoint({required this.label, required this.amount});
}
