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
