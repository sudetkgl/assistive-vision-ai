import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../language_notifier.dart';
import '../services/elevenlabs_tts.dart';
import '../services/voice_command_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'color_mode_screen.dart';
import 'object_mode_screen.dart';
import 'settings_screen.dart';
import 'text_mode_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ElevenLabsTts _tts = ElevenLabsTts();
  final VoiceCommandService _voice = VoiceCommandService();
  bool _voiceListening = false;
  bool _voiceStarted = false;

  @override
  void initState() {
    super.initState();
    languageNotifier.addListener(_onLanguageChanged);

    _tts.onStart = () => _voice.pause();
    _tts.onComplete = () {
      if (!mounted) return;
      // Start STT only after TTS is done — prevents echo loop
      if (!_voiceStarted) {
        _voiceStarted = true;
        _voice.start();
      } else {
        _voice.resume();
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _speakWelcome();
    });

    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await _voice.initialize(
      localeId: S(languageNotifier.value).ttsLocale,
    );
    if (!ok || !mounted) return;

    _voice.onListeningChanged = (listening) {
      if (mounted) setState(() => _voiceListening = listening);
    };

    _registerCommands();
  }

  void _registerCommands() {
    _voice.clearCommands();
    _voice.register(
      ['nesne', 'nesne tespiti', 'birinci', 'object', 'detection', 'görüntü'],
      _openObjectMode,
    );
    _voice.register(
      ['metin', 'metin okuma', 'ikinci', 'text', 'reading', 'yazı', 'oku'],
      _openTextMode,
    );
    _voice.register(
      ['renk', 'renk tespiti', 'üçüncü', 'color', 'colour', 'renkler'],
      _openColorMode,
    );
    _voice.register(
      ['tekrar', 'yeniden', 'repeat', 'söyle', 'anlat'],
      () => _speak(S(languageNotifier.value).repeatSpeech),
    );
  }

  void _openObjectMode() {
    if (!mounted) return;
    final locale = languageNotifier.value;
    _speak(S(locale).openingObjectMode);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ObjectModeScreen(locale: locale)),
    );
  }

  void _openTextMode() {
    if (!mounted) return;
    final locale = languageNotifier.value;
    _speak(S(locale).openingTextMode);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TextModeScreen(locale: locale)),
    );
  }

  void _openColorMode() {
    if (!mounted) return;
    final locale = languageNotifier.value;
    _speak(S(locale).openingColorMode);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ColorModeScreen(locale: locale)),
    );
  }

  void _speakWelcome() {
    final s = S(languageNotifier.value);
    _tts.speak(s.welcomeSpeech, locale: s.ttsLocale);
  }

  void _onLanguageChanged() async {
    await _tts.stop();
    if (mounted) _speakWelcome();
  }

  Future<void> _speak(String text) async {
    _voice.pause(); // stop STT before TTS starts
    await _tts.speak(text, locale: S(languageNotifier.value).ttsLocale);
  }

  @override
  void dispose() {
    languageNotifier.removeListener(_onLanguageChanged);
    _voice.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, locale, _) {
        final s = S(locale);
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(locale),
                  const SizedBox(height: 20),
                  Text(
                    s.selectMode,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.subtitle,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFFB0B8C8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ModeCard(
                    title: s.objectDetection,
                    description: s.objectDetectionDesc,
                    icon: Icons.remove_red_eye_outlined,
                    accentColor: const Color(0xFF2563EB),
                    iconBgColor: const Color(0xFF1E3A5F),
                    iconColor: const Color(0xFF60A5FA),
                    startLabel: s.startLabel,
                    semanticLabel:
                        '${s.objectDetection}. ${s.objectDetectionDesc.replaceAll('\n', ' ')}',
                    onTap: _openObjectMode,
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(
                    title: s.textReading,
                    description: s.textReadingDesc,
                    icon: Icons.text_fields_outlined,
                    accentColor: const Color(0xFF0F9D58),
                    iconBgColor: const Color(0xFF0D3321),
                    iconColor: const Color(0xFF4ADE80),
                    startLabel: s.startLabel,
                    semanticLabel:
                        '${s.textReading}. ${s.textReadingDesc.replaceAll('\n', ' ')}',
                    onTap: _openTextMode,
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(
                    title: s.colorDetection,
                    description: s.colorDetectionDesc,
                    icon: Icons.palette_outlined,
                    accentColor: const Color(0xFF7C3AED),
                    iconBgColor: const Color(0xFF2E1065),
                    iconColor: const Color(0xFFA78BFA),
                    startLabel: s.startLabel,
                    semanticLabel:
                        '${s.colorDetection}. ${s.colorDetectionDesc.replaceAll('\n', ' ')}',
                    onTap: _openColorMode,
                  ),
                  const SizedBox(height: 20),
                  _VoiceIndicator(listening: _voiceListening, locale: locale),
                  const SizedBox(height: 12),
                  Semantics(
                    label: s.repeatGuidanceSemantic,
                    button: true,
                    hint: locale == 'tr'
                        ? 'Sesli yönlendirmeyi yeniden başlatır'
                        : 'Restarts audio guidance',
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => _speak(s.repeatSpeech),
                        icon: const Icon(Icons.volume_up_outlined,
                            size: 20, color: Colors.white),
                        label: Text(
                          s.repeatGuidance,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(
                              color: Color(0xFF334155), width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onTap: (i) {
              if (i == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(String locale) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF4FC3F7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'ASSISTIVE VISION',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4FC3F7),
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Semantics(
          label: locale == 'tr'
              ? 'Dil seçimi, şu an Türkçe'
              : 'Language selection, currently English',
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF181828),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF2A2A3A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['tr', 'en'].map((lang) {
                final isActive = locale == lang;
                return GestureDetector(
                  onTap: () => languageNotifier.value = lang,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      lang.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF888899),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Voice indicator ────────────────────────────────────────────────────────────

class _VoiceIndicator extends StatefulWidget {
  final bool listening;
  final String locale;
  const _VoiceIndicator({required this.listening, required this.locale});

  @override
  State<_VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends State<_VoiceIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_pulse);
    if (widget.listening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_VoiceIndicator old) {
    super.didUpdateWidget(old);
    if (widget.listening && !old.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && old.listening) {
      _pulse.stop();
      _pulse.value = 0.3;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.locale == 'tr'
        ? (widget.listening ? 'Sesli komut dinleniyor' : 'Sesli komut hazır')
        : (widget.listening ? 'Listening for commands' : 'Voice commands ready');

    final hint = widget.locale == 'tr'
        ? '"Nesne tespiti" veya "Metin okuma" deyin'
        : 'Say "Object detection" or "Text reading"';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.listening
              ? const Color(0xFF2563EB).withOpacity(0.5)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (widget.listening
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B))
                    .withOpacity(widget.listening ? _anim.value : 0.5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            widget.listening ? Icons.mic : Icons.mic_none,
            size: 16,
            color: widget.listening
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.listening
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                ),
                if (widget.listening)
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode card ──────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Color iconBgColor;
  final Color iconColor;
  final String startLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.startLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      hint: startLabel,
      child: Material(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF242442), width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accentColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: iconColor, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFB0B8C8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                startLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  color: accentColor, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
