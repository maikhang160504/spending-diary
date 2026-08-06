import 'dart:math';

class AnomalyDetectionService {
  // Hàm tính toán mức độ bất thường (Z-Score)
  double calculateZScore(double currentExpense, List<double> historyExpenses) {
    if (historyExpenses.length < 5)
      return 0.0; // Cần ít nhất 5 mẫu để bắt đầu tính

    // 1. Tính giá trị trung bình (Mean)
    double sum = historyExpenses.fold(0, (prev, element) => prev + element);
    double mean = sum / historyExpenses.length;

    // 2. Tính phương sai (Variance)
    double variance =
        historyExpenses
            .map((e) => (e - mean) * (e - mean))
            .fold(0.0, (prev, element) => prev + element) /
        historyExpenses.length;

    // 3. Tính độ lệch chuẩn (Standard Deviation)
    double standardDeviation = sqrt(variance);

    if (standardDeviation == 0) return 0.0;

    // 4. Tính Z-Score
    return (currentExpense - mean) / standardDeviation;
  }

  // Logic kích hoạt Mascot
  bool shouldTriggerMascot(double zScore) {
    return zScore > 2.5; // Ngưỡng thông thường để coi là "bất thường"
  }
}

// Lớp phụ trợ để lưu tọa độ điểm dữ liệu
class Point {
  final double x; // Ngày
  final double y; // Số dư
  Point(this.x, this.y);
}

class FinancialForecastingService {
  // Hàm dự báo ngày còn lại (Days Remaining)
  int predictDaysRemaining(List<Point> dataPoints) {
    // dataPoints: X là số ngày tính từ đầu tháng, Y là số dư ví tại ngày đó
    int n = dataPoints.length;
    if (n < 2) return 30; // Mặc định 30 ngày nếu chưa đủ dữ liệu

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (var point in dataPoints) {
      sumX += point.x;
      sumY += point.y;
      sumXY += (point.x * point.y);
      sumX2 += (point.x * point.x);
    }

    // 1. Tính độ dốc (Slope - a) trong y = ax + b
    // Công thức hồi quy tuyến tính đơn giản
    double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    // 2. Tính điểm cắt trục tung (Intercept - b)
    double intercept = (sumY - slope * sumX) / n;

    // 3. Giải phương trình tìm x khi y = 0 (Khi tiền bằng 0)
    // 0 = ax + b => x = -b / a
    if (slope >= 0) return 99; // Nếu đang thu nhiều hơn chi, không hết tiền

    double dayMoneyHitsZero = -intercept / slope;
    int daysLeft = (dayMoneyHitsZero - dataPoints.last.x).round();

    return daysLeft > 0 ? daysLeft : 0;
  }
}
