import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageCompressService {
  static const maxLongSide = 2000;
  static const jpegQuality = 70;

  final int maxLongSidePx;
  final int quality;

  const ImageCompressService({
    this.maxLongSidePx = maxLongSide,
    this.quality = jpegQuality,
  });

  String compressToBase64(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('无法解码图片');
    }

    img.Image resized;
    final w = decoded.width;
    final h = decoded.height;
    final longSide = w > h ? w : h;

    if (longSide > maxLongSidePx) {
      final ratio = maxLongSidePx / longSide;
      resized = img.copyResize(
        decoded,
        width: (w * ratio).round(),
        height: (h * ratio).round(),
      );
    } else {
      resized = decoded;
    }

    // TODO: Implement iterative quality reduction loop to enforce 2MB max
    final encoded = img.encodeJpg(resized, quality: quality);
    return 'data:image/jpeg;base64,${base64Encode(encoded)}';
  }
}
