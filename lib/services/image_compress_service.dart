import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageCompressService {
  static const maxLongSide = 2000;
  static const minLongSide = 800;
  static const jpegQuality = 70;
  static const targetBytes = 3 * 1024 * 1024;
  static const scaleDownRatio = 0.85;

  static const _qualitySteps = [70, 60, 50, 40, 30];

  final int maxLongSidePx;
  final int initialQuality;

  const ImageCompressService({
    this.maxLongSidePx = maxLongSide,
    this.initialQuality = jpegQuality,
  });

  String compressToBase64(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('无法解码图片');
    }

    var working = decoded;

    final w = decoded.width;
    final h = decoded.height;
    final originalLongSide = max(w, h);

    if (originalLongSide > maxLongSidePx) {
      final ratio = maxLongSidePx / originalLongSide;
      working = img.copyResize(
        decoded,
        width: (w * ratio).round(),
        height: (h * ratio).round(),
      );
    }

    Uint8List encoded = img.encodeJpg(working, quality: initialQuality);
    if (encoded.length <= targetBytes) {
      return _toBase64(encoded);
    }

    // Try lower quality steps at current size.
    final qualityStartIndex =
        _qualitySteps.indexOf(initialQuality).clamp(0, _qualitySteps.length);
    for (var qi = qualityStartIndex; qi < _qualitySteps.length; qi++) {
      encoded = img.encodeJpg(working, quality: _qualitySteps[qi]);
      if (encoded.length <= targetBytes) {
        return _toBase64(encoded);
      }
    }

    // Still over 3MB: iteratively scale down and retry.
    var currentLongSide = max(working.width, working.height);
    while (currentLongSide > minLongSide) {
      final nextLongSide = (currentLongSide * scaleDownRatio).round();
      currentLongSide = max(nextLongSide, minLongSide);
      final ratio = currentLongSide / max(working.width, working.height);
      working = img.copyResize(
        working,
        width: (working.width * ratio).round(),
        height: (working.height * ratio).round(),
      );

      // Retry all quality steps at the new size.
      for (var qi = 0; qi < _qualitySteps.length; qi++) {
        encoded = img.encodeJpg(working, quality: _qualitySteps[qi]);
        if (encoded.length <= targetBytes) {
          return _toBase64(encoded);
        }
      }
    }

    // Best effort: return the last encoded result at minimum size / quality 30.
    // This may still exceed 3MB for extremely incompressible images.
    return _toBase64(encoded);
  }

  String _toBase64(Uint8List jpgBytes) {
    return 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';
  }
}
