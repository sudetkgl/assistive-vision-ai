import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_strings.dart';
import '../services/color_detection_service.dart';
import '../services/elevenlabs_tts.dart';
import '../services/settings_service.dart';
import '../services/voice_command_service.dart';
import '../widgets/app_bottom_nav.dart';

class ColorModeScreen extends StatefulWidget {
  final String locale;
  const ColorModeScreen({super.key, required this.locale});

  @override
  State<ColorModeScreen> createState() => _ColorModeScreenState();
}

class _ColorModeScreenState extends State<ColorModeScreen> {
  CameraController? _cameraController;
  final ElevenLabsTts _tts = ElevenLabsTts();
  final VoiceCommandService _voice = VoiceCommandService();

  bool _isInitialized = false;
  bool _isActive = false;
  bool _isSpeaking = false;
  bool _isDisposed = false;

  ColorResult? _lastResult;
  int _sampledR = 128, _sampledG = 128, _sampledB = 128;
  String _lastSpokenColor = '';
  DateTime _lastSpokenTime = DateTime(0);
  DateTime _lastFrameTime = DateTime.now();

  S get _s => S(widget.locale);

  static const _accentColor = Color(0xFF7C3AED);
  static const _liveColor = Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    _tts.onStart = () {
      if (mounted) setState(() => _isSpeaking = true);
      _voice.pause();
    };
    _tts.onComplete = () {
      if (mounted) setState(() => _isSpeaking = false);
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
      () { if (mounted) setState(() => _isActive = !_isActive); },
    );
    _voice.register(
      ['tekrar', 'yeniden', 'repeat', 'ne renk', 'renk ne', 'söyle'],
      () {
        if (_lastResult != null) {
          final name = widget.locale == 'tr'
              ? _lastResult!.color.nameTr
              : _lastResult!.color.nameEn;
          _tts.speak(name, locale: _s.ttsLocale);
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
    if (cameras.isEmpty || !mounted) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() => _isInitialized = true);
    _cameraController!.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    if (!_isActive || _isDisposed) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFrameTime).inMilliseconds;
    if (elapsed < 125) return; // ~8 FPS
    _lastFrameTime = now;

    final plane = image.planes[0];
    final (r, g, b) = ColorDetectionService.sampleCenter(
      plane.bytes,
      image.width,
      image.height,
      plane.bytesPerRow,
    );
    final result = ColorDetectionService.detect(r, g, b);
    debugPrint(
      'COLOR fps=${(1000 / elapsed).round()} '
      'rgb=($r,$g,$b) '
      'color=${result.color.nameTr} '
      'deltaE=${result.deltaE.toStringAsFixed(1)}',
    );

    if (mounted) {
      setState(() {
        _lastResult = result;
        _sampledR = r;
        _sampledG = g;
        _sampledB = b;
      });
    }

    _speakIfChanged(result);
  }

  void _speakIfChanged(ColorResult result) {
    final colorName = widget.locale == 'tr'
        ? result.color.nameTr
        : result.color.nameEn;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenTime).inMilliseconds;

    // Same color → wait 3s before repeating; different color → 500ms debounce
    if (colorName == _lastSpokenColor && elapsed < 3000) return;
    if (colorName != _lastSpokenColor && elapsed < 500) return;

    _lastSpokenColor = colorName;
    _lastSpokenTime = now;
    if (SettingsService.instance.vibration) HapticFeedback.lightImpact();
    _tts.speak(colorName, locale: _s.ttsLocale);
  }

  void _toggleActive() {
    setState(() => _isActive = !_isActive);
    if (_isActive) {
      _lastSpokenColor = '';
      _lastSpokenTime = DateTime(0);
      _tts.speak(_s.colorStartedSpeech, locale: _s.ttsLocale);
      if (SettingsService.instance.vibration) HapticFeedback.heavyImpact();
    } else {
      _tts.speak(_s.colorPausedSpeech, locale: _s.ttsLocale);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) { if (i == 0) Navigator.pop(context); },
      ),
      body: Stack(
        children: [
          // Camera preview
          if (_isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: _accentColor),
            ),

          // Crosshair + color swatch
          if (_isInitialized)
            Center(
              child: CustomPaint(
                painter: _CrosshairPainter(
                  swatchColor: _lastResult != null && _isActive
                      ? Color.fromRGBO(_sampledR, _sampledG, _sampledB, 1)
                      : null,
                ),
                size: const Size(200, 200),
              ),
            ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          width: 44, height: 44,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
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
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isActive)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _liveColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _s.colorModeTitle,
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
                  ],
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.7),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isActive && _lastResult != null) ...[
                        Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: Color.fromRGBO(
                                    _sampledR, _sampledG, _sampledB, 1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.white24, width: 1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.locale == 'tr'
                                  ? _lastResult!.color.nameTr
                                  : _lastResult!.color.nameEn,
                              style: TextStyle(
                                color: _isSpeaking
                                    ? _accentColor
                                    : Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(
                            widget.locale == 'tr'
                                ? _lastResult!.color.nameEn
                                : _lastResult!.color.nameTr,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (!_isActive) ...[
                        Text(
                          _s.colorTapHint,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Semantics(
                        label: _isActive
                            ? (widget.locale == 'tr'
                                ? 'Renk tanımayı durdur'
                                : 'Stop color detection')
                            : (widget.locale == 'tr'
                                ? 'Renk tanımayı başlat'
                                : 'Start color detection'),
                        button: true,
                        child: GestureDetector(
                          onTap: _isInitialized ? _toggleActive : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isActive
                                  ? _accentColor
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: _isActive
                                  ? null
                                  : Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              _isActive ? _s.colorPauseBtn : _s.colorStartBtn,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
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

class _CrosshairPainter extends CustomPainter {
  final Color? swatchColor;
  const _CrosshairPainter({this.swatchColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const half = 40.0; // 80×80 swatch box

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    // Horizontal line — left and right of box
    canvas.drawLine(Offset(0, cy), Offset(cx - half - 6, cy), linePaint);
    canvas.drawLine(Offset(cx + half + 6, cy), Offset(size.width, cy), linePaint);

    // Vertical line — above and below box
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - half - 6), linePaint);
    canvas.drawLine(Offset(cx, cy + half + 6), Offset(cx, size.height), linePaint);

    // Color swatch box
    final boxRect = Rect.fromCenter(
        center: Offset(cx, cy), width: 80, height: 80);
    final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(12));

    if (swatchColor != null) {
      canvas.drawRRect(rrect, Paint()..color = swatchColor!);
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.swatchColor != swatchColor;
}
