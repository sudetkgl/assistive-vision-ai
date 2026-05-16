import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../language_notifier.dart';
import '../services/settings_service.dart';
import '../widgets/app_bottom_nav.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, locale, _) {
        return ListenableBuilder(
          listenable: SettingsService.instance,
          builder: (context, _) {
            final s = S(locale);
            final settings = SettingsService.instance;
            return Scaffold(
              backgroundColor: const Color(0xFF0A0A0A),
              bottomNavigationBar: AppBottomNav(
                currentIndex: 2,
                onTap: (i) {
                  if (i == 0) Navigator.pop(context);
                },
              ),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, s),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Section(title: s.sectionAudio, children: [
                              _SettingRow(
                                label: s.settingTtsSpeed,
                                icon: Icons.speed_rounded,
                                child: _SegmentedChoice(
                                  options: [
                                    s.speedSlow,
                                    s.speedNormal,
                                    s.speedFast,
                                  ],
                                  selected: settings.ttsSpeed.index,
                                  onSelected: (i) => settings
                                      .setTtsSpeed(TtsSpeed.values[i]),
                                ),
                              ),
                              const _Divider(),
                              _SettingRow(
                                label: s.settingVolume,
                                icon: Icons.volume_up_rounded,
                                child: _VolumeSlider(
                                  value: settings.volume,
                                  onChanged: (v) => settings.setVolume(v),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            _Section(title: s.sectionDetection, children: [
                              _SettingRow(
                                label: s.settingDescFreq,
                                icon: Icons.timer_outlined,
                                child: _SegmentedChoice(
                                  options: const ['2s', '4s', '6s'],
                                  selected: const [2000, 4000, 6000]
                                      .indexOf(settings.descriptionInterval),
                                  onSelected: (i) =>
                                      settings.setDescriptionInterval(
                                          const [2000, 4000, 6000][i]),
                                ),
                              ),
                              const _Divider(),
                              _SettingRow(
                                label: s.settingVibration,
                                icon: Icons.vibration_rounded,
                                child: Switch.adaptive(
                                  value: settings.vibration,
                                  onChanged: (v) => settings.setVibration(v),
                                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF2563EB),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            _Section(title: s.sectionDisplay, children: [
                              _SettingRow(
                                label: s.settingFontSize,
                                icon: Icons.text_fields_rounded,
                                child: _SegmentedChoice(
                                  options: [
                                    s.fontSmall,
                                    s.fontMedium,
                                    s.fontLarge,
                                  ],
                                  selected: settings.fontSize.index,
                                  onSelected: (i) => settings
                                      .setFontSize(AppFontSize.values[i]),
                                ),
                              ),
                              const _Divider(),
                              _SettingRow(
                                label: s.settingHighContrast,
                                icon: Icons.contrast_rounded,
                                child: Switch.adaptive(
                                  value: settings.highContrast,
                                  onChanged: (v) =>
                                      settings.setHighContrast(v),
                                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF2563EB),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            _Section(title: s.sectionLanguage, children: [
                              _SettingRow(
                                label: s.settingLanguage,
                                icon: Icons.language_rounded,
                                child: _LangToggle(locale: locale),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
      child: Row(
        children: [
          Semantics(
            label: s.locale == 'tr' ? 'Geri' : 'Back',
            button: true,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            s.settingsTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section container ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 1.4,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── Setting row ────────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  const _SettingRow(
      {required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 50, color: Color(0xFF1E293B));
  }
}

// ── Segmented choice ──────────────────────────────────────────────────────────

class _SegmentedChoice extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  const _SegmentedChoice(
      {required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(options.length, (i) {
        final isActive = i == selected;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              options[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Volume slider ─────────────────────────────────────────────────────────────

class _VolumeSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _VolumeSlider({required this.value, required this.onChanged});

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(_VolumeSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: const Color(0xFF2563EB),
          inactiveTrackColor: const Color(0xFF1E293B),
          thumbColor: const Color(0xFF2563EB),
          overlayColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          trackHeight: 4,
        ),
        child: Slider(
          value: _value,
          min: 0,
          max: 1,
          onChanged: (v) => setState(() => _value = v),
          onChangeEnd: widget.onChanged,
        ),
      ),
    );
  }
}

// ── Language toggle ──────────────────────────────────────────────────────────

class _LangToggle extends StatelessWidget {
  final String locale;
  const _LangToggle({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['tr', 'en'].map((lang) {
          final isActive = locale == lang;
          return GestureDetector(
            onTap: () => languageNotifier.value = lang,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF2563EB)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lang.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      isActive ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
