import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  runApp(const AssistiveVisionApp());
}

class AssistiveVisionApp extends StatelessWidget {
  const AssistiveVisionApp({super.key});

  static final ThemeData _highContrastTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFFFF00),
      secondary: Color(0xFF00FFFF),
      surface: Colors.black,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final settings = SettingsService.instance;
        return MaterialApp(
          title: 'Assistive Vision',
          debugShowCheckedModeBanner: false,
          theme: settings.highContrast ? _highContrastTheme : ThemeData.dark(),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
