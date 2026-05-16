import 'dart:ui';

class YoloDetection {
  final String label;
  final double confidence;
  final Rect boundingBox; // normalized 0-1 coords

  const YoloDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

class SceneDescriber {
  String _lang = 'tr';

  void setLanguage(String lang) => _lang = lang;

  static const _labelsTR = {
    'person': 'kişi',
    'car': 'araç', 'truck': 'kamyon', 'bus': 'otobüs',
    'motorcycle': 'motosiklet', 'bicycle': 'bisiklet',
    'chair': 'sandalye', 'couch': 'koltuk', 'bed': 'yatak',
    'dining table': 'masa', 'toilet': 'tuvalet',
    'laptop': 'bilgisayar', 'tv': 'televizyon',
    'cell phone': 'telefon', 'keyboard': 'klavye',
    'bottle': 'şişe', 'cup': 'bardak', 'book': 'kitap',
    'backpack': 'sırt çantası', 'handbag': 'çanta',
    'umbrella': 'şemsiye', 'suitcase': 'bavul',
    'apple': 'elma', 'banana': 'muz', 'pizza': 'pizza',
    'knife': 'bıçak', 'scissors': 'makas',
    'fire hydrant': 'yangın musluğu', 'stop sign': 'dur tabelası',
    'dog': 'köpek', 'cat': 'kedi', 'bird': 'kuş',
  };

  bool _isDangerous(String label) => const {
    'car', 'truck', 'bus', 'motorcycle', 'knife', 'scissors', 'dog',
  }.contains(label);

  bool hasDanger(List<YoloDetection> detections) =>
      detections.any((d) => d.confidence > 0.45 && _isDangerous(d.label));

  String _position(double centerX) {
    if (_lang == 'tr') {
      if (centerX < 0.33) return 'sol tarafınızda';
      if (centerX > 0.66) return 'sağ tarafınızda';
      return 'önünüzde';
    } else {
      if (centerX < 0.33) return 'on your left';
      if (centerX > 0.66) return 'on your right';
      return 'in front of you';
    }
  }

  String _distance(double area) {
    if (_lang == 'tr') {
      if (area > 0.40) return 'çok yakınınızda';
      if (area > 0.20) return 'yaklaşık 1 metre önünüzde';
      if (area > 0.08) return 'yaklaşık 2 metre önünüzde';
      if (area > 0.03) return 'yaklaşık 3 metre önünüzde';
      return 'uzakta';
    } else {
      if (area > 0.40) return 'very close';
      if (area > 0.20) return 'about 1 meter away';
      if (area > 0.08) return 'about 2 meters away';
      if (area > 0.03) return 'about 3 meters away';
      return 'far away';
    }
  }

  double _area(YoloDetection d) =>
      d.boundingBox.width * d.boundingBox.height;

  String describe(List<YoloDetection> detections) {
    final filtered =
        detections.where((d) => d.confidence > 0.45).toList();

    if (filtered.isEmpty) return '';

    final dangerous = filtered.where((d) => _isDangerous(d.label)).toList()
      ..sort((a, b) => _area(b).compareTo(_area(a)));
    final normal = filtered.where((d) => !_isDangerous(d.label)).toList()
      ..sort((a, b) => _area(b).compareTo(_area(a)));

    final toDescribe = [...dangerous, ...normal].take(3);

    final sentences = <String>[];
    for (final det in toDescribe) {
      final label = _lang == 'tr'
          ? (_labelsTR[det.label] ?? det.label)
          : det.label;
      final pos = _position(det.boundingBox.center.dx);
      final dist = _distance(_area(det));
      final danger = _isDangerous(det.label);

      if (_lang == 'tr') {
        sentences.add(danger
            ? 'Dikkat! $dist $pos $label var.'
            : '$dist $pos $label var.');
      } else {
        sentences.add(danger
            ? 'Warning! $label $dist $pos.'
            : '$label $dist $pos.');
      }
    }

    return sentences.join(' ');
  }
}
