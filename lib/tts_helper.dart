import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'services/settings_service.dart';

/// Configures TTS for the most natural-sounding output on iOS/Android.
/// Uses [SettingsService] defaults when speechRate/volume are not specified.
Future<void> configureTts(
  FlutterTts tts, {
  required String locale,
  double? speechRate,
  double pitch = 1.0,
  double? volume,
}) async {
  final rate = speechRate ?? SettingsService.instance.ttsSpeedRate;
  final vol = volume ?? SettingsService.instance.volume;

  if (Platform.isIOS) {
    await tts.setSharedInstance(true);
    await tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );

    // Pick a premium voice for the locale if available
    final voices = (await tts.getVoices) as List?;
    if (voices != null) {
      final localePrefix = locale.split('-').first.toLowerCase();
      final preferred = voices.cast<Map>().where((v) {
        final name = (v['name'] as String? ?? '').toLowerCase();
        final lang = (v['locale'] as String? ?? '').toLowerCase();
        return lang.startsWith(localePrefix) &&
            (name.contains('premium') || name.contains('enhanced'));
      }).toList();

      if (preferred.isNotEmpty) {
        await tts.setVoice({
          'name': preferred.first['name'] as String,
          'locale': preferred.first['locale'] as String,
        });
      } else {
        final any = voices.cast<Map>().where((v) {
          final lang = (v['locale'] as String? ?? '').toLowerCase();
          return lang.startsWith(localePrefix);
        }).toList();
        if (any.isNotEmpty) {
          await tts.setVoice({
            'name': any.first['name'] as String,
            'locale': any.first['locale'] as String,
          });
        }
      }
    }
  }

  await tts.setLanguage(locale);
  await tts.setSpeechRate(rate);
  await tts.setPitch(pitch);
  await tts.setVolume(vol);
}
