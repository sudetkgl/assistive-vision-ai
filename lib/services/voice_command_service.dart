import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCommandService {
  final SpeechToText _stt = SpeechToText();

  bool _available = false;
  bool _listening = false;
  bool _paused = true;
  bool _started = false;
  bool _ttsActive = false; // TTS is speaking — block STT and discard results
  String _localeId = 'tr-TR';
  int _errorCount = 0;

  final List<({List<String> keywords, VoidCallback action})> _commands = [];

  void Function(bool)? onListeningChanged;

  Future<bool> initialize({String localeId = 'tr-TR'}) async {
    _localeId = localeId;
    _available = await _stt.initialize(
      onError: (e) {
        _errorCount++;
        debugPrint('STT error [$_errorCount]: ${e.errorMsg}');
        _setListening(false);
        if (_paused || !_started || _ttsActive) return;

        if (_errorCount > 5) {
          // Circuit breaker — too many consecutive errors, back off 3s
          Future.delayed(const Duration(seconds: 3), () {
            _errorCount = 0;
            if (!_paused && _started && !_ttsActive) _listen();
          });
        } else {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!_paused && _started && !_ttsActive) _listen();
          });
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _setListening(false);
          if (!_paused && _started && !_ttsActive) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!_paused && _started && !_ttsActive) _listen();
            });
          }
        }
      },
    );
    return _available;
  }

  void register(List<String> keywords, VoidCallback action) {
    _commands.add((keywords: keywords, action: action));
  }

  void clearCommands() => _commands.clear();

  void start() {
    _paused = false;
    _started = true;
    _listen();
  }

  /// Call when TTS starts speaking — immediately stops STT.
  void pause() {
    _ttsActive = true;
    _paused = true;
    if (_listening) _stt.stop();
    _setListening(false);
  }

  /// Call when TTS finishes speaking — resumes STT after a short delay.
  void resume() {
    _ttsActive = false;
    _paused = false;
    if (_started) {
      // Small extra delay on top of ElevenLabsTts's own 1500ms cooldown,
      // giving room reverb time to decay before the mic opens again.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!_paused && _started && !_ttsActive) _listen();
      });
    }
  }

  void _listen() {
    if (!_available || _listening || _paused || !_started || _ttsActive) return;
    _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          _handle(result.recognizedWords.toLowerCase().trim());
        }
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(cancelOnError: false),
    );
    _setListening(true);
  }

  void _handle(String words) {
    // Discard anything recognized while TTS is playing — it's echo.
    if (words.isEmpty || _ttsActive) return;

    _errorCount = 0; // Successful recognition resets the error circuit breaker.
    debugPrint('Voice recognized: "$words"');

    for (final cmd in _commands) {
      if (cmd.keywords.any((k) => words.contains(k))) {
        cmd.action();
        return;
      }
    }
  }

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    onListeningChanged?.call(value);
  }

  bool get isListening => _listening && !_paused;

  void dispose() {
    _paused = true;
    _started = false;
    _ttsActive = false;
    _stt.cancel();
  }
}
