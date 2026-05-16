import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsSpeed { slow, normal, fast }

enum AppFontSize { small, medium, large }

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  TtsSpeed _ttsSpeed = TtsSpeed.normal;
  int _descriptionInterval = 2000;
  double _volume = 1.0;
  bool _vibration = true;
  bool _highContrast = false;
  AppFontSize _fontSize = AppFontSize.medium;

  TtsSpeed get ttsSpeed => _ttsSpeed;
  int get descriptionInterval => _descriptionInterval;
  double get volume => _volume;
  bool get vibration => _vibration;
  bool get highContrast => _highContrast;
  AppFontSize get fontSize => _fontSize;

  double get ttsSpeedRate => switch (_ttsSpeed) {
        TtsSpeed.slow => 0.30,
        TtsSpeed.normal => 0.42,
        TtsSpeed.fast => 0.60,
      };

  double get fontScale => switch (_fontSize) {
        AppFontSize.small => 0.90,
        AppFontSize.medium => 1.00,
        AppFontSize.large => 1.18,
      };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _ttsSpeed = TtsSpeed.values[p.getInt('ttsSpeed') ?? 1];
    _descriptionInterval = p.getInt('descriptionInterval') ?? 2000;
    _volume = p.getDouble('volume') ?? 1.0;
    _vibration = p.getBool('vibration') ?? true;
    _highContrast = p.getBool('highContrast') ?? false;
    _fontSize = AppFontSize.values[p.getInt('fontSize') ?? 1];
    notifyListeners();
  }

  Future<void> setTtsSpeed(TtsSpeed v) async {
    _ttsSpeed = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('ttsSpeed', v.index);
  }

  Future<void> setDescriptionInterval(int v) async {
    _descriptionInterval = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('descriptionInterval', v);
  }

  Future<void> setVolume(double v) async {
    _volume = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setDouble('volume', v);
  }

  Future<void> setVibration(bool v) async {
    _vibration = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('vibration', v);
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('highContrast', v);
  }

  Future<void> setFontSize(AppFontSize v) async {
    _fontSize = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('fontSize', v.index);
  }
}
