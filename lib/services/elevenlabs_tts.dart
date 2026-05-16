import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import '../tts_helper.dart';
import 'settings_service.dart';

/// OpenAI TTS service with local file caching and flutter_tts fallback.
/// Audio files are cached permanently so each phrase is only fetched once.
class ElevenLabsTts {
  static final Map<String, String> _fileCache = {};
  static const int _maxApiFailures = 3;
  static int _apiFailureCount = 0; // shared across all instances

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallback = FlutterTts();
  bool _fallbackReady = false;
  bool _startingNew = false;

  void Function()? onStart;
  void Function()? onComplete;

  ElevenLabsTts() {
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _startingNew = false; // new audio confirmed playing — safe to clear flag
        onStart?.call();
      }
      if (state == PlayerState.completed) _scheduleComplete();
      // stopped fires when we call stop() to start new audio;
      // _startingNew guards against that spurious complete callback.
      if (state == PlayerState.stopped && !_startingNew) _scheduleComplete();
    });
  }

  // 1500ms delay prevents STT from picking up TTS echo/reverb
  void _scheduleComplete() {
    Future.delayed(const Duration(milliseconds: 1500), () => onComplete?.call());
  }

  Future<void> speak(String text, {required String locale}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _startingNew = true;
    await _player.stop();
    // Do NOT reset _startingNew here — the PlayerState.stopped event fires
    // asynchronously AFTER this await returns. _startingNew is cleared only
    // when PlayerState.playing confirms the new audio has actually started.

    final key = '${locale}_${trimmed.hashCode}';
    String? filePath = _fileCache[key];

    if (filePath != null && await File(filePath).exists()) {
      await _player.setVolume(SettingsService.instance.volume);
      await _player.play(DeviceFileSource(filePath));
      return;
    }

    if (_apiFailureCount < _maxApiFailures) {
      try {
        filePath = await _fetchFromApi(trimmed, locale);
        _fileCache[key] = filePath;
        _apiFailureCount = 0;
        await _player.setVolume(SettingsService.instance.volume);
        await _player.play(DeviceFileSource(filePath));
        return;
      } catch (e) {
        _apiFailureCount++;
        debugPrint('OpenAI TTS failed ($e), using system TTS');
      }
    }

    await _speakFallback(trimmed, locale);
  }

  Future<void> stop() async {
    await _player.stop();
    await _fallback.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _fallback.stop();
  }

  // ---------------------------------------------------------------------------

  Future<String> _fetchFromApi(String text, String locale) async {
    final voice = locale.startsWith('tr')
        ? AppConfig.openAiVoiceTR
        : AppConfig.openAiVoiceEN;

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/audio/speech'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': AppConfig.openAiModel,
            'input': text,
            'voice': voice,
            'response_format': 'mp3',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('OpenAI TTS ${response.statusCode}: ${response.body}');
      throw Exception('HTTP ${response.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/oai_${text.hashCode.abs()}_${locale.replaceAll('-', '')}.mp3');
    await file.writeAsBytes(response.bodyBytes);
    debugPrint('OpenAI TTS cached: ${file.path}');
    return file.path;
  }

  Future<void> _speakFallback(String text, String locale) async {
    if (!_fallbackReady) {
      await configureTts(_fallback, locale: locale);
      _fallback.setStartHandler(() {
        _startingNew = false;
        onStart?.call();
      });
      _fallback.setCompletionHandler(() => _scheduleComplete());
      _fallbackReady = true;
    } else {
      await _fallback.setLanguage(locale);
      await _fallback.setSpeechRate(SettingsService.instance.ttsSpeedRate);
      await _fallback.setVolume(SettingsService.instance.volume);
    }
    await _fallback.speak(text);
  }
}
