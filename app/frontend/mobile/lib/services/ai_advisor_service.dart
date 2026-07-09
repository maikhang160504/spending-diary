import 'dart:async';

class AIAdvisorService {
  static Future<String> askFinancialQuestion(String prompt) async {
    // Giả lập hoặc gọi backend AI advisor
    await Future.delayed(const Duration(milliseconds: 600));
    final lower = prompt.toLowerCase();
    if (lower.contains('danh mục') || lower.contains('chi tiêu theo')) {
      return 'MiMo nhận thấy bạn chi tiêu nhiều cho Thiết yếu & Ẩm thực. Việc cân đối lại 5-10% cho Tích lũy sẽ giúp vững vàng tài chính hơn!';
    } else if (lower.contains('dòng tiền') || lower.contains('thu chi')) {
      return 'Dòng tiền ròng duy trì nhịp độ ổn định. Hãy theo dõi sát các ngày có chi tiêu bất thường vào cuối tuần nhé!';
    } else if (lower.contains('tiết kiệm') || lower.contains('xu hướng')) {
      return 'Xu hướng tích lũy đang đi đúng hướng. Thiết lập tự động trích lập 15% thu nhập vào đầu kỳ sẽ giúp tối ưu hóa thặng dư!';
    } else if (lower.contains('lũy kế') || lower.contains('hạn mức') || lower.contains('burn rate')) {
      return 'Tốc độ tiêu hao hạn mức hiện đang ở ngưỡng an toàn. Hãy giữ mức chi tiêu bình quân dưới 400.000đ/ngày trong phần còn lại của kỳ.';
    }
    return 'MiMo khuyên bạn luôn ghi chép chi tiêu đều đặn hàng ngày để AI phân tích chính xác nhất!';
  }
}
