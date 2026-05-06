import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';

const Map<String, Map<String, dynamic>> assistiveCategories = {
  'car':          {'label': 'Araç',            'priority': 1, 'danger': true},
  'bus':          {'label': 'Araç',            'priority': 1, 'danger': true},
  'truck':        {'label': 'Araç',            'priority': 1, 'danger': true},
  'motorcycle':   {'label': 'Araç',            'priority': 1, 'danger': true},
  'bicycle':      {'label': 'Bisiklet',        'priority': 1, 'danger': true},
  'person':       {'label': 'İnsan',           'priority': 2, 'danger': false},
  'chair':        {'label': 'Engel',           'priority': 3, 'danger': false},
  'bench':        {'label': 'Engel',           'priority': 3, 'danger': false},
  'couch':        {'label': 'Engel',           'priority': 3, 'danger': false},
  'potted plant': {'label': 'Engel',           'priority': 3, 'danger': false},
  'bottle':       {'label': 'Küçük nesne',     'priority': 4, 'danger': false},
  'cup':          {'label': 'Küçük nesne',     'priority': 4, 'danger': false},
  'cell phone':   {'label': 'Kişisel eşya',    'priority': 4, 'danger': false},
  'book':         {'label': 'Kişisel eşya',    'priority': 4, 'danger': false},
  'laptop':       {'label': 'Elektronik eşya', 'priority': 4, 'danger': false},
};

class ObjectModeScreen extends StatefulWidget {
  const ObjectModeScreen({super.key});

  @override
  State<ObjectModeScreen> createState() => _ObjectModeScreenState();
}

class _ObjectModeScreenState extends State<ObjectModeScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final FlutterTts _tts = FlutterTts();
  final Battery _battery = Battery();

  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 640;

  bool _isInitialized = false;
  bool _isAnalyzing = false;
  bool _isSpeaking = false;
  String _statusText = 'Başlatılıyor...';
  String _detectionLabel = '';
  bool _isDanger = false;
  String _lastSpokenMessage = '';
  DateTime _lastSpokenTime = DateTime.now().subtract(const Duration(seconds: 10));
  DateTime _lastFrameTime = DateTime.now();
  int _fps = 5;

  // Performans metrikleri
  int _actualFps = 0;
  int _prepMs = 0;
  int _inferMs = 0;
  int _totalMs = 0;
  int _frameCount = 0;
  DateTime _fpsWindowStart = DateTime.now();

  late AnimationController _waveController;

  static const _blueColor = Color(0xFF4FC3F7);
  static const _dangerColor = Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _initAll();
  }

  Future<void> _initAll() async {
    await _initTts();
    await _requestPermissions();
    await _initCamera();
    await _loadModel();
    _monitorBattery();
    _startStream();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
      _waveController.repeat(reverse: true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
      _waveController.stop();
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() => _statusText = 'Model yükleniyor...');
  }

  Future<void> _loadModel() async {
    // Load labels
    final labelData = await rootBundle.loadString('assets/models/labels.txt');
    _labels = labelData.trim().split('\n');

    // Load TFLite interpreter
    final interpreterOptions = InterpreterOptions()..threads = 2;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/yolo.tflite',
      options: interpreterOptions,
    );

    final inputShape = _interpreter!.getInputTensor(0).shape;
    _inputSize = inputShape[1]; // e.g. 640

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _statusText = 'Dinleniyor...';
      });
    }
  }

  void _startStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isAnalyzing) return;
      final now = DateTime.now();
      final intervalMs = (1000 / _fps).round();
      if (now.difference(_lastFrameTime).inMilliseconds < intervalMs) return;
      _lastFrameTime = now;
      await _analyzeFrame(image);
    });
  }

  void _monitorBattery() {
    Timer.periodic(const Duration(minutes: 1), (_) async {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          if (level < 20) {
            _fps = 3;
          } else if (level < 50) {
            _fps = 8;
          } else {
            _fps = 15;
          }
        });
      }
    });
  }

  String _getPosition(double xCenter, double frameWidth) {
    if (xCenter < frameWidth / 3) return 'sol tarafta';
    if (xCenter < 2 * frameWidth / 3) return 'önünde';
    return 'sağ tarafta';
  }

  Future<void> _speak(String message) async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenTime).inMilliseconds;
    // Aynı mesajı 5 saniye içinde tekrarlama; farklı mesaj için 2 saniye bekle
    if (message == _lastSpokenMessage && elapsed < 5000) return;
    if (elapsed < 2000) return;
    _lastSpokenMessage = message;
    _lastSpokenTime = now;
    await _tts.speak(message);
  }

  Future<Float32List> _preprocessImageAsync(CameraImage image) {
    return compute(_preprocessBGRA, _PreprocessArgs(
      bytes: image.planes[0].bytes,
      srcW: image.width,
      srcH: image.height,
      dstSize: _inputSize,
    ));
  }

  // Parse YOLOv8 output tensor [1, 84, 8400]
  // Rows 0-3: cx, cy, w, h (normalized)
  // Rows 4-83: class scores (no separate objectness in YOLOv8)
  List<Map<String, dynamic>> _parseOutput(
      List<List<List<double>>> output, double confThreshold) {
    const int numClasses = 80;
    final int numBoxes = output[0][0].length; // 8400

    final List<Map<String, dynamic>> detections = [];

    for (int i = 0; i < numBoxes; i++) {
      // Find best class
      int bestClass = 0;
      double bestScore = 0.0;
      for (int c = 0; c < numClasses; c++) {
        final double score = output[0][4 + c][i];
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestScore < confThreshold) continue;
      if (bestClass >= _labels.length) continue;

      final double cx = output[0][0][i];
      final double cy = output[0][1][i];
      final double bw = output[0][2][i];
      final double bh = output[0][3][i];

      // Convert to x1,y1,x2,y2 (still normalized 0-1)
      final double x1 = cx - bw / 2;
      final double y1 = cy - bh / 2;
      final double x2 = cx + bw / 2;
      final double y2 = cy + bh / 2;

      detections.add({
        'class': bestClass,
        'tag': _labels[bestClass].trim(),
        'score': bestScore,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
      });
    }

    return _nms(detections, 0.4);
  }

  List<Map<String, dynamic>> _nms(
      List<Map<String, dynamic>> boxes, double iouThreshold) {
    boxes.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final List<Map<String, dynamic>> result = [];
    final List<bool> suppressed = List.filled(boxes.length, false);

    for (int i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;
      result.add(boxes[i]);
      for (int j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;
        if (boxes[i]['class'] != boxes[j]['class']) continue;
        if (_iou(boxes[i], boxes[j]) > iouThreshold) suppressed[j] = true;
      }
    }
    return result;
  }

  double _iou(Map<String, dynamic> a, Map<String, dynamic> b) {
    final double ix1 = max(a['x1'] as double, b['x1'] as double);
    final double iy1 = max(a['y1'] as double, b['y1'] as double);
    final double ix2 = min(a['x2'] as double, b['x2'] as double);
    final double iy2 = min(a['y2'] as double, b['y2'] as double);
    final double iw = max(0, ix2 - ix1);
    final double ih = max(0, iy2 - iy1);
    final double intersection = iw * ih;
    final double aArea = (a['x2'] - a['x1']) * (a['y2'] - a['y1']);
    final double bArea = (b['x2'] - b['x1']) * (b['y2'] - b['y1']);
    final double union = aArea + bArea - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    if (!_isInitialized || _interpreter == null) return;
    _isAnalyzing = true;

    final totalWatch = Stopwatch()..start();

    try {
      // Preprocessing süresi
      final prepWatch = Stopwatch()..start();
      final Float32List inputData = await _preprocessImageAsync(image);
      final inputTensor = inputData.reshape([1, _inputSize, _inputSize, 3]);
      prepWatch.stop();

      // Output tensörü hazırla
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final List<List<List<double>>> outputTensor = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List.filled(outputShape[2], 0.0),
        ),
      );

      // Inference süresi
      final inferWatch = Stopwatch()..start();
      _interpreter!.run(inputTensor, outputTensor);
      inferWatch.stop();

      final detections = _parseOutput(outputTensor, 0.4);
      final filtered = detections
          .where((d) => assistiveCategories.containsKey(d['tag'] as String))
          .toList();

      // Gerçek FPS hesapla (1 saniyelik pencere)
      _frameCount++;
      final windowMs = DateTime.now().difference(_fpsWindowStart).inMilliseconds;
      if (windowMs >= 1000) {
        _actualFps = (_frameCount * 1000 / windowMs).round();
        _frameCount = 0;
        _fpsWindowStart = DateTime.now();
      }

      totalWatch.stop();
      _prepMs = prepWatch.elapsedMilliseconds;
      _inferMs = inferWatch.elapsedMilliseconds;
      _totalMs = totalWatch.elapsedMilliseconds;

      debugPrint('PERF prep=${_prepMs}ms infer=${_inferMs}ms '
          'total=${_totalMs}ms fps=$_actualFps');

      if (filtered.isEmpty) {
        if (mounted) {
          setState(() {
            _detectionLabel = '';
            _isDanger = false;
            _statusText = 'prep:${_prepMs}ms  infer:${_inferMs}ms  $_actualFps fps';
          });
        }
        return;
      }

      filtered.sort((a, b) {
        final pa = assistiveCategories[a['tag']]!['priority'] as int;
        final pb = assistiveCategories[b['tag']]!['priority'] as int;
        return pa.compareTo(pb);
      });

      final top = filtered.first;
      final tag = top['tag'] as String;
      final xCenter = ((top['x1'] as double) + (top['x2'] as double)) / 2;
      final position = _getPosition(xCenter, 1.0);
      final label = assistiveCategories[tag]!['label'] as String;
      final danger = assistiveCategories[tag]!['danger'] as bool;

      final message = '$label $position';
      await _speak(message);

      if (mounted) {
        setState(() {
          _detectionLabel = message;
          _isDanger = danger;
          _statusText =
              '${filtered.length} nesne  prep:${_prepMs}ms  infer:${_inferMs}ms  $_actualFps fps';
        });
      }
    } catch (e) {
      debugPrint('analyzeFrame error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _tts.stop();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isDanger ? _dangerColor : _blueColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Kamera tam ekran
          if (_isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: _blueColor),
            ),

          // Tehlike overlay
          if (_isDanger)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _dangerColor, width: 3),
                  ),
                ),
              ),
            ),

          // Üst bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _blueColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'NESNE TESPİTİ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_actualFps fps  ${_totalMs}ms',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Alt panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSpeaking) ...[
                        _TtsWave(
                            animation: _waveController,
                            color: accentColor),
                        const SizedBox(height: 12),
                      ],

                      if (_detectionLabel.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: accentColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isDanger
                                    ? Icons.warning_amber_rounded
                                    : Icons.location_on_outlined,
                                color: accentColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _detectionLabel,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Text(
                        _statusText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Top-level sınıf ve fonksiyon — compute() ile ayrı isolate'te çalışır
class _PreprocessArgs {
  final Uint8List bytes;
  final int srcW;
  final int srcH;
  final int dstSize;
  const _PreprocessArgs({
    required this.bytes,
    required this.srcW,
    required this.srcH,
    required this.dstSize,
  });
}

Float32List _preprocessBGRA(_PreprocessArgs args) {
  final int w = args.srcW;
  final int h = args.srcH;
  final int size = args.dstSize;
  final Uint8List bytes = args.bytes;
  final Float32List input = Float32List(size * size * 3);
  final double scaleX = w / size;
  final double scaleY = h / size;
  int idx = 0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int srcX = (x * scaleX).floor().clamp(0, w - 1);
      final int srcY = (y * scaleY).floor().clamp(0, h - 1);
      final int p = (srcY * w + srcX) * 4;
      input[idx++] = bytes[p + 2] / 255.0; // R
      input[idx++] = bytes[p + 1] / 255.0; // G
      input[idx++] = bytes[p + 0] / 255.0; // B
    }
  }
  return input;
}

class _TtsWave extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  const _TtsWave({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (i) {
          final height = 6.0 + (i % 3 + 1) * 6.0 * animation.value;
          return Container(
            width: 3,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
