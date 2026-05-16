import 'dart:math';
import 'dart:typed_data';
import 'turkish_color_db.dart';

class ColorResult {
  final TurkishColor color;
  final double deltaE;
  final int r, g, b;
  const ColorResult({
    required this.color,
    required this.deltaE,
    required this.r,
    required this.g,
    required this.b,
  });
}

class ColorDetectionService {
  ColorDetectionService._();

  static List<double> _rgbToLab(int r, int g, int b) {
    double rd = r / 255.0, gd = g / 255.0, bd = b / 255.0;

    rd = rd > 0.04045 ? pow((rd + 0.055) / 1.055, 2.4).toDouble() : rd / 12.92;
    gd = gd > 0.04045 ? pow((gd + 0.055) / 1.055, 2.4).toDouble() : gd / 12.92;
    bd = bd > 0.04045 ? pow((bd + 0.055) / 1.055, 2.4).toDouble() : bd / 12.92;

    double x = (rd * 0.4124 + gd * 0.3576 + bd * 0.1805) / 0.95047;
    double y = (rd * 0.2126 + gd * 0.7152 + bd * 0.0722) / 1.00000;
    double z = (rd * 0.0193 + gd * 0.1192 + bd * 0.9505) / 1.08883;

    double f(double t) =>
        t > 0.008856 ? pow(t, 1.0 / 3.0).toDouble() : 7.787 * t + 16.0 / 116.0;

    return [116.0 * f(y) - 16.0, 500.0 * (f(x) - f(y)), 200.0 * (f(y) - f(z))];
  }

  static double _deltaE(List<double> a, List<double> b) => sqrt(
        pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2) + pow(a[2] - b[2], 2),
      );

  static ColorResult detect(int r, int g, int b) {
    final inputLab = _rgbToLab(r, g, b);
    TurkishColor? best;
    double bestDelta = double.infinity;

    for (final color in TurkishColorDB.colors) {
      final delta = _deltaE(inputLab, _rgbToLab(color.r, color.g, color.b));
      if (delta < bestDelta) {
        bestDelta = delta;
        best = color;
      }
    }

    return ColorResult(color: best!, deltaE: bestDelta, r: r, g: g, b: b);
  }

  // BGRA8888 format: each pixel is [B, G, R, A] — same format used by
  // the camera package when imageFormatGroup is bgra8888.
  // bytesPerRow may include padding, so use it as row stride.
  static (int, int, int) sampleCenter(
    Uint8List bytes,
    int width,
    int height,
    int bytesPerRow,
  ) {
    final cx = width ~/ 2;
    final cy = height ~/ 2;
    int totalR = 0, totalG = 0, totalB = 0, count = 0;

    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final idx = (cy + dy) * bytesPerRow + (cx + dx) * 4;
        if (idx >= 0 && idx + 2 < bytes.length) {
          totalB += bytes[idx];     // B at offset 0
          totalG += bytes[idx + 1]; // G at offset 1
          totalR += bytes[idx + 2]; // R at offset 2
          count++;
        }
      }
    }

    if (count == 0) return (128, 128, 128);
    return (totalR ~/ count, totalG ~/ count, totalB ~/ count);
  }
}
