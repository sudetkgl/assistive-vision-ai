import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'object_mode_screen.dart';
import 'text_mode_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    setState(() => _ttsReady = true);
    // İlk frame render olduktan sonra karşıla
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        await _tts.speak(
          'Hoş geldiniz. Nesne tespiti veya metin okuma modunu seçin.',
        );
      }
    });
  }

  Future<void> _speak(String text) async {
    if (_ttsReady) await _tts.speak(text);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst etiket
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4FC3F7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ASSISTIVE VISION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4FC3F7),
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                'Mod Seçin',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Çevrenizi tanımlamak için bir mod seçin.\nUygulama sesli yönlendirme yapar.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              // Nesne Tespiti
              _ModeCard(
                title: 'Nesne Tespiti',
                description:
                    'Çevredeki araçları, engelleri ve\nnesneleri gerçek zamanlı sesli tanımlar.',
                icon: Icons.remove_red_eye_outlined,
                color: const Color(0xFF4FC3F7),
                onTap: () {
                  _speak('Nesne tespiti açılıyor.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ObjectModeScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Metin Okuma
              _ModeCard(
                title: 'Metin Okuma',
                description:
                    'Tabelaları, belgeleri ve yazılı\nmetinleri sesli olarak okur.',
                icon: Icons.text_fields_outlined,
                color: const Color(0xFF81C784),
                onTap: () {
                  _speak('Metin okuma açılıyor.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TextModeScreen()),
                  );
                },
              ),

              const Spacer(),

              // Sesli tekrar butonu
              Center(
                child: GestureDetector(
                  onTap: () => _speak(
                    'Nesne tespiti veya metin okuma modunu seçin.',
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up_outlined,
                            size: 16, color: Color(0xFF4FC3F7)),
                        SizedBox(width: 8),
                        Text(
                          'Yönlendirmeyi Tekrarla',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w500,
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
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E1E1E)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
