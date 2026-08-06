
/// Rule-based AI advisor sử dụng dữ liệu thực tế để tạo nhận xét thông minh.
/// Không gọi API — phân tích dựa trên số liệu thực được truyền vào.
class AIAdvisorService {
  // ─── 1. Dòng tiền (Cashflow) ──────────────────────────────────────────────
  /// [totalIncome]: Tổng thu kỳ này
  /// [totalExpense]: Tổng chi kỳ này
  /// [periodLabel]: Ví dụ "Tháng 7/2026", "Tuần hiện tại"
  /// [breakdownValues]: Danh sách [{income, expense}] theo tuần/tháng/năm
  static String analyzeCashflow({
    required int totalIncome,
    required int totalExpense,
    required String periodLabel,
    List<Map<String, dynamic>> breakdownValues = const [],
  }) {
    final net = totalIncome - totalExpense;
    final savingRate =
        totalIncome > 0 ? (net / totalIncome * 100).round() : 0;

    if (totalIncome == 0 && totalExpense == 0) {
      return 'Chưa có dữ liệu thu chi cho kỳ $periodLabel. Hãy bắt đầu ghi chép để MiMo đưa ra nhận xét!';
    }

    if (totalIncome == 0) {
      return 'Kỳ $periodLabel chưa có khoản thu nào được ghi nhận. Chi tiêu hiện tại là ${_fmtM(totalExpense)}. Hãy bổ sung khoản thu để theo dõi dòng tiền chính xác hơn!';
    }

    if (net < 0) {
      final deficit = -net;
      return 'Kỳ $periodLabel bội chi ${_fmtM(deficit)} (chi vượt thu ${_pct(deficit, totalIncome)}%). '
          'Tổng thu ${_fmtM(totalIncome)} — tổng chi ${_fmtM(totalExpense)}. '
          'Hãy rà soát lại các khoản chi lớn nhất để cân bằng dòng tiền!';
    }

    if (savingRate >= 30) {
      return 'Tuyệt vời! Kỳ $periodLabel tích lũy ròng ${_fmtM(net)} (tỉ lệ ${savingRate}%). '
          'Thu ${_fmtM(totalIncome)}, chi ${_fmtM(totalExpense)}. '
          'Duy trì mức này và cân nhắc đầu tư phần thặng dư để tối ưu hoá tài sản!';
    }

    if (savingRate >= 10) {
      return 'Kỳ $periodLabel dòng tiền dương: tích lũy ${_fmtM(net)} (${savingRate}%). '
          'Thu ${_fmtM(totalIncome)}, chi ${_fmtM(totalExpense)}. '
          'Mục tiêu lý tưởng là tiết kiệm 20%+ — bạn đang trên đà tốt!';
    }

    // savingRate >= 0 but < 10
    return 'Kỳ $periodLabel thu chi gần cân bằng: tích lũy ròng chỉ ${_fmtM(net)} (${savingRate}%). '
        'Thu ${_fmtM(totalIncome)}, chi ${_fmtM(totalExpense)}. '
        'Cố gắng cắt giảm thêm để nâng tỉ lệ tiết kiệm lên 15–20%!';
  }

  // ─── 2. Phân bổ danh mục ──────────────────────────────────────────────────
  /// [cats]: Danh sách {categoryLabel, amount, percent} sắp xếp theo amount giảm dần
  /// [recordType]: "expense" hoặc "income"
  /// [totalAmount]: Tổng số tiền kỳ này
  /// [periodLabel]: Mô tả kỳ
  static String analyzeCategorySpending({
    required List<Map<String, dynamic>> cats,
    required String recordType,
    required int totalAmount,
    required String periodLabel,
  }) {
    if (cats.isEmpty || totalAmount == 0) {
      final typeLabel = recordType == 'expense' ? 'chi tiêu' : 'thu nhập';
      return 'Chưa có dữ liệu $typeLabel cho kỳ $periodLabel. Hãy ghi chép thêm để MiMo phân tích chi tiết!';
    }

    final typeLabel = recordType == 'expense' ? 'chi tiêu' : 'thu nhập';
    final top = cats.take(3).toList();
    final topLabel = top.map((c) {
      final pct = ((c['percent'] as num?)?.toDouble() ?? 0).round();
      return '${c['categoryLabel']} (${pct}%)';
    }).join(', ');

    if (recordType == 'expense') {
      final topCat = cats.first;
      final topPct = ((topCat['percent'] as num?)?.toDouble() ?? 0).round();
      final topAmt = (topCat['amount'] as num?)?.toInt() ?? 0;

      // Tìm danh mục có mom change lớn nhất (tăng)
      Map<String, dynamic>? biggestRise;
      for (final c in cats) {
        final mom = (c['momChange'] as num?)?.toDouble();
        if (mom != null && mom > 20) {
          if (biggestRise == null ||
              mom > ((biggestRise['momChange'] as num?)?.toDouble() ?? 0)) {
            biggestRise = c;
          }
        }
      }

      String msg =
          'Kỳ $periodLabel, chi ${_fmtM(totalAmount)} — danh mục lớn nhất: $topLabel. '
          '"${topCat['categoryLabel']}" chiếm $topPct% (${_fmtM(topAmt)}).';

      if (biggestRise != null) {
        final momVal = (biggestRise['momChange'] as num?)?.toDouble() ?? 0;
        msg +=
            ' Lưu ý: "${biggestRise['categoryLabel']}" tăng ${momVal.round()}% so với kỳ trước — hãy kiểm tra lại!';
      } else if (topPct >= 50) {
        msg +=
            ' Tỷ trọng quá cao — cân nhắc phân bổ lại để giảm phụ thuộc vào 1 danh mục!';
      } else {
        msg += ' Phân bổ $typeLabel khá cân đối trong kỳ này!';
      }

      return msg;
    } else {
      // income
      final topCat = cats.first;
      final topPct = ((topCat['percent'] as num?)?.toDouble() ?? 0).round();
      return 'Kỳ $periodLabel, thu ${_fmtM(totalAmount)} — nguồn thu chính: $topLabel. '
          '"${topCat['categoryLabel']}" chiếm $topPct% — '
          '${topPct >= 70 ? "nguồn thu khá tập trung, cân nhắc đa dạng hoá thu nhập!" : "cơ cấu thu nhập đa dạng, tiếp tục duy trì!"}';
    }
  }

  // ─── 3. Lũy kế vs Ngân sách ───────────────────────────────────────────────
  /// [limit]: Hạn mức ngân sách kỳ
  /// [currentSpent]: Đã chi lũy kế
  /// [periodLabel]: Mô tả kỳ
  /// [daysElapsed]: Số ngày đã trôi qua trong kỳ
  /// [totalDays]: Tổng số ngày của kỳ
  static String analyzeCumulativeBudget({
    required double limit,
    required double currentSpent,
    required String periodLabel,
    int daysElapsed = 0,
    int totalDays = 0,
  }) {
    if (limit <= 0) {
      return 'Chưa thiết lập hạn mức ngân sách cho kỳ $periodLabel. Hãy vào mục Giới hạn để thiết lập để MiMo theo dõi giúp bạn!';
    }

    final pct = (currentSpent / limit * 100).clamp(0, 200);
    final remaining = (limit - currentSpent).clamp(0, limit);

    // Tính tốc độ chi tiêu lý tưởng
    String paceMsg = '';
    if (totalDays > 0 && daysElapsed > 0) {
      final expectedSpent = limit * daysElapsed / totalDays;
      final pace = currentSpent / expectedSpent;
      if (pace > 1.3) {
        final daysLeft = totalDays - daysElapsed;
        final dailyAllowed =
            daysLeft > 0 ? (remaining / daysLeft).round() : 0;
        paceMsg =
            ' Tốc độ chi nhanh hơn kế hoạch ${((pace - 1) * 100).round()}% — chỉ nên chi tối đa ${_fmtK(dailyAllowed)}/ngày trong ${daysLeft} ngày còn lại.';
      } else if (pace < 0.7) {
        paceMsg = ' Tốc độ chi tiêu đang khá thận trọng, tốt!';
      }
    }

    if (pct >= 100) {
      return 'Cảnh báo! Đã vượt hạn mức ngân sách kỳ $periodLabel — chi ${_fmtM(currentSpent.round())} / hạn mức ${_fmtM(limit.round())} (${pct.round()}%). '
          'Cần dừng các khoản chi không thiết yếu ngay bây giờ!$paceMsg';
    }

    if (pct >= 80) {
      return 'Cẩn thận! Đã dùng ${pct.round()}% ngân sách kỳ $periodLabel — còn lại ${_fmtM(remaining.round())} trên tổng ${_fmtM(limit.round())}.$paceMsg';
    }

    if (pct >= 50) {
      return 'Kỳ $periodLabel đã dùng ${pct.round()}% ngân sách (${_fmtM(currentSpent.round())}/${_fmtM(limit.round())}). '
          'Còn ${_fmtM(remaining.round())} — đang ở ngưỡng cần theo dõi chặt.$paceMsg';
    }

    return 'Tốt! Kỳ $periodLabel mới dùng ${pct.round()}% ngân sách — còn ${_fmtM(remaining.round())} dự phòng.$paceMsg '
        'Tiếp tục duy trì nhịp chi tiêu hợp lý!';
  }

  // ─── 4. So sánh cộng đồng ─────────────────────────────────────────────────
  /// [totalUser]: Tổng chi của người dùng
  /// [totalAvg]: Trung bình cộng đồng cùng phân khúc
  /// [ageGroup]: Nhóm tuổi
  /// [jobTitle]: Nghề nghiệp
  /// [compareData]: [{categoryLabel, userAmount, avgAmount}]
  /// [periodLabel]: Mô tả kỳ
  static String analyzePeerCompare({
    required int totalUser,
    required int totalAvg,
    required String periodLabel,
    String? ageGroup,
    String? jobTitle,
    List<Map<String, dynamic>> compareData = const [],
  }) {
    if (totalAvg == 0) {
      return 'Chưa đủ dữ liệu cộng đồng để so sánh cho kỳ $periodLabel. Khi có đủ người dùng cùng phân khúc, MiMo sẽ đưa ra phân tích chi tiết!';
    }

    final diff = totalUser - totalAvg;
    final diffPct = (diff.abs() / totalAvg * 100).round();
    final groupDesc =
        (ageGroup != null && jobTitle != null) ? '$ageGroup - $jobTitle' : 'nhóm của bạn';

    // Tìm danh mục bạn chi nhiều hơn nhóm nhất
    Map<String, dynamic>? biggestOverspend;
    for (final d in compareData) {
      final userAmt = (d['userAmount'] as num?)?.toInt() ?? 0;
      final avgAmt = (d['avgAmount'] as num?)?.toInt() ?? 0;
      if (avgAmt > 0 && userAmt > avgAmt) {
        final over = userAmt - avgAmt;
        if (biggestOverspend == null ||
            over > (((biggestOverspend['userAmount'] as num?)?.toInt() ?? 0) -
                ((biggestOverspend['avgAmount'] as num?)?.toInt() ?? 0))) {
          biggestOverspend = d;
        }
      }
    }

    if (diff > 0) {
      String msg =
          'Kỳ $periodLabel bạn chi ${_fmtM(totalUser)}, cao hơn trung bình $groupDesc ${_fmtM(totalAvg)} ($diffPct%).';
      if (biggestOverspend != null) {
        final userAmt = (biggestOverspend['userAmount'] as num?)?.toInt() ?? 0;
        final avgAmt = (biggestOverspend['avgAmount'] as num?)?.toInt() ?? 0;
        msg +=
            ' Danh mục "${biggestOverspend['categoryLabel']}" đang cao hơn nhóm ${_fmtM(userAmt - avgAmt)} — đây là điểm cần cải thiện!';
      }
      return msg;
    }

    if (diff < 0) {
      return 'Tuyệt vời! Kỳ $periodLabel bạn chi ${_fmtM(totalUser)}, thấp hơn trung bình $groupDesc ${_fmtM(totalAvg)} ($diffPct%). '
          'Bạn đang quản lý chi tiêu hiệu quả hơn nhóm tương đồng!';
    }

    return 'Kỳ $periodLabel chi tiêu của bạn (${_fmtM(totalUser)}) gần như bằng với mức trung bình $groupDesc. '
        'Hãy xem chi tiết từng danh mục để tìm cơ hội tối ưu hoá!';
  }

  // ─── 5. Xu hướng tiết kiệm ────────────────────────────────────────────────
  /// [totalIncome]: Tổng thu kỳ này
  /// [totalExpense]: Tổng chi kỳ này
  /// [netSaving]: Tích lũy ròng = thu - chi
  /// [savingRate]: Tỉ lệ tích lũy (0–100)
  /// [periodLabel]: Mô tả kỳ
  /// [chartValues]: Danh sách tích lũy ròng từng điểm (để phát hiện xu hướng)
  static String analyzeSavingTrend({
    required int totalIncome,
    required int totalExpense,
    required int netSaving,
    required double savingRate,
    required String periodLabel,
    List<double> chartValues = const [],
  }) {
    if (totalIncome == 0 && totalExpense == 0) {
      return 'Chưa có dữ liệu cho kỳ $periodLabel. Hãy ghi chép thu chi để MiMo phân tích xu hướng tiết kiệm!';
    }

    // Phân tích xu hướng tăng/giảm qua chartValues
    String trendMsg = '';
    if (chartValues.length >= 3) {
      final first = chartValues.take(chartValues.length ~/ 2).toList();
      final last = chartValues.skip(chartValues.length ~/ 2).toList();
      final avgFirst = first.reduce((a, b) => a + b) / first.length;
      final avgLast = last.reduce((a, b) => a + b) / last.length;
      if (avgLast > avgFirst * 1.15) {
        trendMsg = ' Xu hướng tích lũy đang tăng dần — rất tích cực!';
      } else if (avgLast < avgFirst * 0.85) {
        trendMsg = ' Xu hướng tích lũy đang giảm so với đầu kỳ — cần chú ý!';
      }
    }

    if (totalIncome == 0) {
      return 'Kỳ $periodLabel chỉ có chi (${_fmtM(totalExpense)}), không ghi nhận thu nhập. '
          'Đây có thể là kỳ đặc biệt — hãy bổ sung khoản thu để theo dõi chính xác hơn!';
    }

    final ratePct = savingRate.round();

    if (netSaving < 0) {
      return 'Kỳ $periodLabel bội chi ${_fmtM(-netSaving)} — thu ${_fmtM(totalIncome)}, chi ${_fmtM(totalExpense)}. '
          'Tỉ lệ tích lũy âm ${ratePct.abs()}%.$trendMsg '
          'Xem lại các khoản chi lớn và cắt giảm những chi tiêu chưa cần thiết!';
    }

    if (ratePct >= 30) {
      return 'Xuất sắc! Kỳ $periodLabel tích lũy ${_fmtM(netSaving)} (${ratePct}% thu nhập).$trendMsg '
          'Với tỉ lệ này, hãy cân nhắc đầu tư phần thặng dư để sinh lời dài hạn!';
    }

    if (ratePct >= 15) {
      return 'Tốt! Kỳ $periodLabel tiết kiệm được ${_fmtM(netSaving)} (${ratePct}% thu nhập).$trendMsg '
          'Hãy cố gắng duy trì hoặc nâng lên 20%+ bằng cách trích tự động đầu kỳ!';
    }

    if (ratePct > 0) {
      return 'Kỳ $periodLabel tích lũy ${_fmtM(netSaving)} (${ratePct}% thu nhập) — còn thấp.$trendMsg '
          'Thử áp dụng quy tắc 50/30/20: 50% nhu cầu, 30% mong muốn, 20% tích lũy!';
    }

    return 'Kỳ $periodLabel thu chi gần bằng nhau — tích lũy ròng ${_fmtM(netSaving)}.$trendMsg '
        'Hãy đặt mục tiêu tiết kiệm cụ thể mỗi kỳ để xây dựng quỹ dự phòng!';
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static String _fmtM(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}tr';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).round()}K';
    }
    return '${amount}đ';
  }

  static String _fmtK(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}tr';
    if (amount >= 1000) return '${(amount / 1000).round()}K';
    return '${amount}đ';
  }

  static int _pct(int part, int total) =>
      total > 0 ? (part / total * 100).round() : 0;
}
