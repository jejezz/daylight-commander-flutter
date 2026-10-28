// From jejezz/application-release-templates common/ @ conventions-v1.
//
// 설정 창(settings_dialog.dart)에 놓는 테마·언어·글자 크기·색 구성 위젯.
// 순환 버튼은 쓰지 않는다 — 지금 상태와 다음 상태가 보이지 않는다 (theming.md §3).
// 앱 바 오른쪽 끝의 순서: … | 글자 크기 대신 설정 | 정보

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../presentation/theme/app_theme.dart';
import '../presentation/theme/font_scale_provider.dart';
import '../presentation/widgets/tool_icon.dart';
import 'app_settings.dart';

/// 언어 이름은 그 언어로 쓴다 — 잘못 골라도 읽고 되돌아올 수 있게.
const _languages = [(Locale('ko'), '한국어'), (Locale('en'), 'English')];

Widget _themeIcon(ThemeMode mode) => ToolIcon(
      switch (mode) {
        ThemeMode.system => 'icons8-system-theme.svg',
        ThemeMode.light => 'icons8-light-theme.svg',
        ThemeMode.dark => 'icons8-dark-theme.svg',
      },
      size: 18,
    );

String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };

class ThemeSegmentedButton extends StatelessWidget {
  const ThemeSegmentedButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<ThemeMode>(
      segments: [
        for (final mode in ThemeMode.values)
          ButtonSegment(value: mode, icon: _themeIcon(mode), label: Text(_themeLabel(l10n, mode))),
      ],
      selected: {settings.themeMode},
      onSelectionChanged: (s) => settings.setThemeMode(s.single),
    );
  }
}

class LanguageSegmentedButton extends StatelessWidget {
  const LanguageSegmentedButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: '', label: Text(l10n.languageSystemShort)),
        for (final (locale, name) in _languages) ButtonSegment(value: locale.languageCode, label: Text(name)),
      ],
      selected: {settings.locale?.languageCode ?? ''},
      onSelectionChanged: (s) => settings.setLocale(s.single.isEmpty ? null : Locale(s.single)),
    );
  }
}

/// 글자 크기: 작게 · 보통 · 크게. Riverpod의 [fontScaleProvider]를 쓴다.
class FontScaleSegmentedButton extends ConsumerWidget {
  const FontScaleSegmentedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scale = ref.watch(fontScaleProvider);
    String label(double s) => switch (s) {
          0.9 => l10n.fontScaleSmall,
          1.15 => l10n.fontScaleLarge,
          _ => l10n.fontScaleNormal,
        };
    return SegmentedButton<double>(
      showSelectedIcon: false,
      segments: [for (final s in fontScaleChoices) ButtonSegment(value: s, label: Text(label(s)))],
      selected: {scale},
      onSelectionChanged: (s) => ref.read(fontScaleProvider.notifier).setScale(s.single),
    );
  }
}

String paletteLabel(AppLocalizations l10n, ColorPalette p) => switch (p) {
      ColorPalette.saturn => l10n.settingsPaletteSaturn,
      ColorPalette.teal => l10n.settingsPaletteTeal,
      ColorPalette.amber => l10n.settingsPaletteAmber,
      ColorPalette.rose => l10n.settingsPaletteRose,
      ColorPalette.slate => l10n.settingsPaletteSlate,
      ColorPalette.highContrast => l10n.settingsPaletteHighContrast,
    };

/// 색 구성(color theme) 선택 칩. 색마다 주색 원을 앞에 보여 준다.
class PaletteChoice extends StatelessWidget {
  const PaletteChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in ColorPalette.values)
          ChoiceChip(
            selected: settings.palette == p,
            showCheckmark: false,
            // 고대비는 주색 하나가 아니라 배경·글자 전부를 바꾸므로 색 원 대신 반반 칠한 아이콘으로 구분한다.
            avatar: p == ColorPalette.highContrast
                ? Icon(Icons.contrast, size: 16, color: scheme.onSurface)
                : Icon(Icons.circle, size: 14, color: p.primaryFor(Theme.of(context).brightness)),
            label: Text(paletteLabel(l10n, p)),
            onSelected: (_) => settings.setPalette(p),
          ),
      ],
    );
  }
}
