import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import '../l10n/app_strings.dart';
import '../services/elevenlabs_tts.dart';
import '../services/scene_describer.dart';
import '../services/settings_service.dart';
import '../services/voice_command_service.dart';
import '../widgets/app_bottom_nav.dart';

class ObjectModeScreen extends StatefulWidget {
  final String locale;
  const ObjectModeScreen({super.key, required this.locale});

  @override
  State<ObjectModeScreen> createState() => _ObjectModeScreenState();
}

class _ObjectModeScreenState extends State<ObjectModeScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  final ElevenLabsTts _tts = ElevenLabsTts();
  final SceneDescriber _describer = SceneDescriber();
  final Battery _battery = Battery();

  Interpreter? _interpreter;
  List<String> _labels = [];
  int _inputSize = 640;

  bool _isInitialized = false;
  bool _isAnalyzing = false;
  bool _isSpeaking = false;
  late String _statusText;
  String _detectionLabel = '';
  bool _isDanger = false;
  String _lastSpokenMessage = '';
  DateTime _lastSpokenTime =
      DateTime.now().subtract(const Duration(seconds: 10));
  DateTime _lastFrameTime = DateTime.now();
  int _fps = 5;

  int _actualFps = 0;
  int _prepMs = 0;
  int _inferMs = 0;
  int _totalMs = 0;
  int _frameCount = 0;
  DateTime _fpsWindowStart = DateTime.now();

  int _objectCount = 0;
  String _prevDetectionLabel = '';
  bool _showDebugInfo = false;
  bool _isDisposed = false;
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  late AnimationController _waveController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final VoiceCommandService _voice = VoiceCommandService();

  static const _blueColor = Color(0xFF4FC3F7);
  static const _dangerColor = Color(0xFFFF5252);
  static const _liveColor = Color(0xFF22C55E);

  S get _s => S(widget.locale);

  @override
  void initState() {
    super.initState();
    _statusText = _s.starting;
    _describer.setLanguage(widget.locale);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.35, end: 1.0).animate(_pulseController);
    _tts.onStart = () {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
      _waveController.repeat(reverse: true);
      _voice.pause();
    };
    _tts.onComplete = () {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      _waveController.stop();
      _voice.resume();
    };
    _initAll();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await _voice.initialize(localeId: _s.ttsLocale);
    if (!ok || !mounted) return;
    _voice.register(
      ['durdur', 'dur', 'stop', 'sustur', 'pause'],
      () => _tts.stop(),
    );
    _voice.register(
      ['tekrar', 'yeniden', 'repeat', 'söyle', 'ne var'],
      () {
        if (_detectionLabel.isNotEmpty) {
          _tts.speak(_detectionLabel, locale: _s.ttsLocale);
        }
      },
    );
    _voice.register(
      ['geri', 'çıkış', 'back', 'ana', 'anasayfa', 'çık'],
      () { if (mounted) Navigator.pop(context); },
    );
    _voice.start();
  }

  Future<void> _initAll() async {
    await _requestPermissions();
    await _initCamera();
    await _loadModel();
    _monitorBattery();
    _startStream();
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
    if (mounted) setState(() => _statusText = _s.loadingModel);
  }

  Future<void> _loadModel() async {
    final labelData = await rootBundle.loadString('assets/models/labels.txt');
    _labels = labelData.trim().split('\n');

    final interpreterOptions = InterpreterOptions()..threads = 2;

    if (Platform.isIOS) {
      try {
        interpreterOptions.addDelegate(CoreMlDelegate());
        debugPrint('CoreML delegate etkinleştirildi');
      } catch (e) {
        debugPrint('CoreML delegate kullanılamıyor, CPU\'ya geçiliyor: $e');
      }
    }

    _interpreter = await Interpreter.fromAsset(
      'assets/models/yolo.tflite',
      options: interpreterOptions,
    );

    final inputShape = _interpreter!.getInputTensor(0).shape;
    _inputSize = inputShape[1];

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _statusText = _s.listening;
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

  void _onTitleTap() {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds > 800) _tapCount = 0;
    _tapCount++;
    _lastTapTime = now;
    if (_tapCount >= 3) {
      _tapCount = 0;
      if (mounted) setState(() => _showDebugInfo = !_showDebugInfo);
    }
  }

  Future<void> _speak(String message) async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenTime).inMilliseconds;
    if (message == _lastSpokenMessage && elapsed < 5000) return;
    if (elapsed < SettingsService.instance.descriptionInterval) return;
    _lastSpokenMessage = message;
    _lastSpokenTime = now;
    _voice.pause(); // stop STT before TTS starts
    await _tts.speak(message, locale: _s.ttsLocale);
  }

  Future<Float32List> _preprocessImageAsync(CameraImage image) {
    return compute(_preprocessBGRA, _PreprocessArgs(
      bytes: image.planes[0].bytes,
      srcW: image.width,
      srcH: image.height,
      dstSize: _inputSize,
    ));
  }

  List<Map<String, dynamic>> _parseOutput(
      List<List<List<double>>> output, double confThreshold) {
    const int numClasses = 80;
    final int numBoxes = output[0][0].length;

    final List<Map<String, dynamic>> detections = [];

    for (int i = 0; i < numBoxes; i++) {
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
    boxes.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double));
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
    if (!_isInitialized || _interpreter == null || _isDisposed) return;
    _isAnalyzing = true;

    final totalWatch = Stopwatch()..start();

    try {
      final prepWatch = Stopwatch()..start();
      final Float32List inputData = await _preprocessImageAsync(image);
      prepWatch.stop();

      // Re-check after async gap — screen may have been disposed
      if (_isDisposed || _interpreter == null) return;

      final inputTensor = inputData.reshape([1, _inputSize, _inputSize, 3]);
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final List<List<List<double>>> outputTensor = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List.filled(outputShape[2], 0.0),
        ),
      );

      final inferWatch = Stopwatch()..start();
      _interpreter!.run(inputTensor, outputTensor);
      inferWatch.stop();

      final detections = _parseOutput(outputTensor, 0.4);

      final yoloDetections = detections.map((d) => YoloDetection(
        label: d['tag'] as String,
        confidence: d['score'] as double,
        boundingBox: Rect.fromLTRB(
          d['x1'] as double, d['y1'] as double,
          d['x2'] as double, d['y2'] as double,
        ),
      )).toList();

      _frameCount++;
      final windowMs =
          DateTime.now().difference(_fpsWindowStart).inMilliseconds;
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

      final description = _describer.describe(yoloDetections);
      final hasDanger = _describer.hasDanger(yoloDetections);

      if (description != _prevDetectionLabel) {
        if (SettingsService.instance.vibration) HapticFeedback.mediumImpact();
        _prevDetectionLabel = description;
      }

      if (mounted) {
        setState(() {
          _detectionLabel = description;
          _isDanger = hasDanger;
          _objectCount = yoloDetections.length;
        });
      }

      if (description.isNotEmpty) {
        await _speak(description);
      }
    } catch (e) {
      debugPrint('analyzeFrame error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _waveController.dispose();
    _pulseController.dispose();
    _voice.dispose();
    _tts.dispose();
    if (_cameraController?.value.isInitialized == true) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream().then((_) {
          _cameraController!.dispose();
        });
      } else {
        _cameraController!.dispose();
      }
    }
    final interp = _interpreter;
    _interpreter = null;
    interp?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isDanger ? _dangerColor : _blueColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) {
          if (i == 0) Navigator.pop(context);
        },
      ),
      body: Stack(
        children: [
          if (_isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: _blueColor),
            ),

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

          // Top bar
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
                    Semantics(
                      label: widget.locale == 'tr' ? 'Geri' : 'Back',
                      button: true,
                      hint: widget.locale == 'tr'
                          ? 'Ana ekrana dön'
                          : 'Go back to home screen',
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _onTitleTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (_, __) => Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _liveColor
                                      .withOpacity(_pulseAnimation.value),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _s.objectModeTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (_isInitialized) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _liveColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _s.liveLabel,
                                  style: const TextStyle(
                                    color: _liveColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_showDebugInfo)
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

          // Bottom panel
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
                            animation: _waveController, color: accentColor),
                        const SizedBox(height: 12),
                      ],

                      if (_detectionLabel.isNotEmpty)
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 96),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: accentColor.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _isDanger
                                        ? Icons.warning_amber_rounded
                                        : Icons.location_on_outlined,
                                    color: accentColor,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _detectionLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _s.objectsDetectedPlain(_objectCount),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_detectionLabel.isEmpty)
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
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
