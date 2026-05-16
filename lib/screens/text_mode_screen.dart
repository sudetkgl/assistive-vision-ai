import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_strings.dart';
import '../services/elevenlabs_tts.dart';
import '../services/voice_command_service.dart';
import '../widgets/app_bottom_nav.dart';

class TextModeScreen extends StatefulWidget {
  final String locale;
  const TextModeScreen({super.key, required this.locale});

  @override
  State<TextModeScreen> createState() => _TextModeScreenState();
}

class _TextModeScreenState extends State<TextModeScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final ElevenLabsTts _tts = ElevenLabsTts();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  late String _statusText;
  List<String> _detectedTexts = [];

  int _captureMs = 0;
  int _ocrMs = 0;
  int _totalMs = 0;
  int _scanCount = 0;
  int _blockCount = 0;
  bool _showMetrics = false;

  late AnimationController _waveController;
  final VoiceCommandService _voice = VoiceCommandService();

  static const _accentColor = Color(0xFF2563EB);
  static const _dotColor = Color(0xFF4ADE80);

  S get _s => S(widget.locale);

  @override
  void initState() {
    super.initState();
    _statusText = _s.starting;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
      ['tara', 'scan', 'fotoğraf', 'çek', 'oku', 'başlat'],
      _readText,
    );
    _voice.register(
      ['durdur', 'dur', 'stop', 'sustur'],
      () => _tts.stop(),
    );
    _voice.register(
      ['tekrar', 'yeniden', 'repeat', 'söyle', 'oku'],
      () {
        if (_detectedTexts.isNotEmpty) {
          _voice.pause();
          _tts.speak(_detectedTexts.join('. '), locale: _s.ttsLocale);
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
    await Permission.camera.request();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _statusText = _s.tapToScan;
      });
    }
  }

  Future<void> _readText() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusText = _s.scanning;
      _detectedTexts = [];
    });

    final totalWatch = Stopwatch()..start();

    try {
      final captureWatch = Stopwatch()..start();
      final image = await _cameraController!.takePicture();
      captureWatch.stop();

      final ocrWatch = Stopwatch()..start();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      ocrWatch.stop();

      totalWatch.stop();

      final allTexts = recognized.blocks
          .map((b) => b.text.trim())
          .where((t) => t.length > 2)
          .toList();

      final displayTexts = allTexts.take(5).toList();

      _captureMs = captureWatch.elapsedMilliseconds;
      _ocrMs = ocrWatch.elapsedMilliseconds;
      _totalMs = totalWatch.elapsedMilliseconds;
      _blockCount = recognized.blocks.length;
      _scanCount++;

      debugPrint(
        'OCR PERF #$_scanCount '
        'capture=${_captureMs}ms '
        'ocr=${_ocrMs}ms '
        'total=${_totalMs}ms '
        'blocks=$_blockCount '
        'filtered=${allTexts.length}',
      );

      setState(() {
        _detectedTexts = displayTexts;
        _statusText = allTexts.isEmpty
            ? _s.noTextFound
            : _s.textBlocks(allTexts.length, _ocrMs);
      });

      _voice.pause(); // stop STT before TTS starts
      if (allTexts.isEmpty) {
        await _tts.speak(_s.noTextDetected, locale: _s.ttsLocale);
      } else {
        await _tts.speak(allTexts.join('. '), locale: _s.ttsLocale);
      }
    } catch (e) {
      totalWatch.stop();
      debugPrint('OCR ERROR: $e');
      setState(() => _statusText = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _voice.dispose();
    _cameraController?.dispose();
    _tts.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: CircularProgressIndicator(color: _accentColor),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _s.textModeTitle,
                            style: const TextStyle(
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
                    Semantics(
                      label: widget.locale == 'tr'
                          ? 'Performans metrikleri'
                          : 'Performance metrics',
                      button: true,
                      hint: widget.locale == 'tr'
                          ? 'Teknik detayları göster veya gizle'
                          : 'Show or hide technical details',
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showMetrics = !_showMetrics),
                        child: Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _showMetrics
                                ? _accentColor.withOpacity(0.2)
                                : Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: _showMetrics
                                ? Border.all(
                                    color: _accentColor.withOpacity(0.5))
                                : null,
                          ),
                          child: Icon(Icons.speed,
                              color:
                                  _showMetrics ? _accentColor : Colors.white54,
                              size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Metrics overlay
          if (_showMetrics && _scanCount > 0)
            Positioned(
              top: 90,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accentColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MetricRow(
                        label: 'capture',
                        value: '${_captureMs}ms',
                        color: Colors.white70),
                    const SizedBox(height: 2),
                    _MetricRow(
                        label: 'ocr',
                        value: '${_ocrMs}ms',
                        color: _accentColor),
                    const SizedBox(height: 2),
                    _MetricRow(
                        label: 'total',
                        value: '${_totalMs}ms',
                        color: Colors.white),
                    const SizedBox(height: 2),
                    _MetricRow(
                        label: _s.metricBlock,
                        value: '$_blockCount',
                        color: Colors.white70),
                    const SizedBox(height: 2),
                    _MetricRow(
                        label: _s.metricScan,
                        value: '#$_scanCount',
                        color: Colors.white54),
                  ],
                ),
              ),
            ),

          if (_isProcessing)
            Positioned.fill(
              child: _ScanLine(color: _accentColor),
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
                  stops: const [0.0, 0.6, 1.0],
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
                            color: _accentColor),
                        const SizedBox(height: 12),
                      ],

                      if (_detectedTexts.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 160),
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _accentColor.withOpacity(0.3)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _detectedTexts
                                  .map((t) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• $t',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],

                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      Semantics(
                        label: _s.readTextBtnSemantic,
                        button: true,
                        hint: widget.locale == 'tr'
                            ? 'Metni taramak için butona bas'
                            : 'Press to scan text',
                        child: GestureDetector(
                          onTap: _isProcessing ? null : _readText,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 64),
                            decoration: BoxDecoration(
                              color: _isProcessing
                                  ? _accentColor.withOpacity(0.3)
                                  : _accentColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.document_scanner_outlined,
                                              color: Colors.white,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            _s.readTextBtn,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
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

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ScanLine extends StatefulWidget {
  final Color color;
  const _ScanLine({required this.color});

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _ScanLinePainter(_anim.value, widget.color),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScanLinePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, color, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
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
