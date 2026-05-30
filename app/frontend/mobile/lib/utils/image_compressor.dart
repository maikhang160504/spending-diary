import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Nén ảnh trước khi upload để giảm băng thông và tăng tốc xử lý phía server.
///
/// Trả về đường dẫn file đã nén; nếu nén thất bại (định dạng lạ, plugin lỗi)
/// thì trả lại [srcPath] gốc để luồng upload vẫn chạy bình thường.
///
/// - [maxSize]: cạnh dài tối đa (px). Ảnh story dùng ~1280, bill OCR giữ ~1600
///   để chữ vẫn đọc được.
/// - [quality]: chất lượng JPEG (0-100).
Future<String> compressForUpload(
  String srcPath, {
  int maxSize = 1280,
  int quality = 80,
}) async {
  try {
    final src = File(srcPath);
    if (!await src.exists()) return srcPath;

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final targetPath = '${dir.path}/upload_$stamp.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      src.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxSize,
      minHeight: maxSize,
      format: CompressFormat.jpeg,
    );
    if (result == null) return srcPath;

    // Chỉ dùng bản nén nếu thực sự nhỏ hơn bản gốc.
    final origLen = await src.length();
    final newLen = await File(result.path).length();
    return newLen < origLen ? result.path : srcPath;
  } catch (_) {
    return srcPath;
  }
}
