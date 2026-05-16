import 'package:flutter/material.dart';
import '../language_notifier.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int)? onTap;

  const AppBottomNav({super.key, this.currentIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, locale, _) {
        final isTr = locale == 'tr';
        return BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: isTr ? 'Ana' : 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_rounded),
              label: isTr ? 'Geçmiş' : 'History',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              label: isTr ? 'Ayarlar' : 'Settings',
            ),
          ],
        );
      },
    );
  }
}
