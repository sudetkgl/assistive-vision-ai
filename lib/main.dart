import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AssistiveVisionApp());
}

class AssistiveVisionApp extends StatelessWidget {
  const AssistiveVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistive Vision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
