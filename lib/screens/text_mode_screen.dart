import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class TextModeScreen extends StatefulWidget {
  const TextModeScreen({super.key});

  @override
  State<TextModeScreen> createState() => _TextModeScreenState();
}

class _TextModeScreenState extends State<TextModeScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final FlutterTts _tts = FlutterTts();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _statusText = 'Başlatılıyor...';
  List<String> _detectedTexts = [];

  // Performans metrikleri
  int _captureMs = 0;
  int _ocrMs = 0;
  int _totalMs = 0;
  int _scanCount = 0;
  int _blockCount = 0;
  bool _showMetrics = true;

  late AnimationController _waveController;

  static const _accentColor = Color(0xFF81C784);

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
    await Permission.camera.request();
    await _initCamera();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.45);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
      _waveController.repeat(reverse: true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
      _waveController.stop();
    });
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
        _statusText = 'Metin okumak için butona bas';
      });
    }
  }

  Future<void> _readText() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Taranıyor...';
      _detectedTexts = [];
    });

    final totalWatch = Stopwatch()..start();

    try {
      // Fotoğraf çekme süresi
      final captureWatch = Stopwatch()..start();
      final image = await _cameraController!.takePicture();
      captureWatch.stop();

      // OCR işleme süresi
      final ocrWatch = Stopwatch()..start();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      ocrWatch.stop();

      totalWatch.stop();

      final allTexts = recognized.blocks
          .map((b) => b.text.trim())
          .where((t) => t.length > 2)
          .toList();

      // En fazla 5 blok göster, tamamını seslendir
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
            ? 'Metin bulunamadı'
            : '${allTexts.length} metin bloğu · ${_ocrMs}ms';
      });

      if (allTexts.isEmpty) {
        await _tts.speak('Metin algılanamadı');
      } else {
        await _tts.speak(allTexts.join('. '));
      }
    } catch (e) {
      totalWatch.stop();
      debugPrint('OCR ERROR: $e');
      setState(() => _statusText = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _cameraController?.dispose();
    _tts.stop();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Kamera tam ekran
          if (_isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
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
                              color: Color(0xFF81C784),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'METİN OKUMA',
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
                    // Metrik toggle butonu
                    GestureDetector(
                      onTap: () => setState(() => _showMetrics = !_showMetrics),
                      child: Container(
                        padding: const EdgeInsets.all(8),
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
                            color: _showMetrics
                                ? _accentColor
                                : Colors.white54,
                            size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Performans metrikleri overlay
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
                  border:
                      Border.all(color: _accentColor.withOpacity(0.3)),
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
                        label: 'blok',
                        value: '$_blockCount',
                        color: Colors.white70),
                    const SizedBox(height: 2),
                    _MetricRow(
                        label: 'tarama',
                        value: '#$_scanCount',
                        color: Colors.white54),
                  ],
                ),
              ),
            ),

          // Tarama çizgisi animasyonu
          if (_isProcessing)
            Positioned.fill(
              child: _ScanLine(color: _accentColor),
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
                      // TTS dalgası
                      if (_isSpeaking) ...[
                        _TtsWave(
                            animation: _waveController,
                            color: _accentColor),
                        const SizedBox(height: 12),
                      ],

                      // Algılanan metinler
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

                      // Durum metni
                      Text(
                        _statusText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Buton
                      GestureDetector(
                        onTap: _isProcessing ? null : _readText,
                        child: Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _isProcessing
                                ? _accentColor.withOpacity(0.3)
                                : _accentColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.document_scanner_outlined,
                                          color: Colors.black, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'METİN OKU',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
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
