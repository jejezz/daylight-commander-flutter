// From jejezz/application-release-templates common/ @ conventions-v1.
//
// 테마·언어 전환 UI (conventions/theming.md §3, localization.md §4).
//   데스크톱: 앱 바 아이콘 → 체크 표시가 있는 팝업 메뉴. 순환 버튼은 쓰지
//            않는다 — 지금 상태와 다음 상태가 보이지 않는다.
//   모바일:   설정 화면의 SegmentedButton.
// 앱 바 오른쪽 끝의 순서: … | ThemeMenuButton | LanguageMenuButton | 정보

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../presentation/widgets/tool_icon.dart';
import 'app_settings.dart';

/// 언어 이름은 그 언어로 쓴다 — 잘못 골라도 읽고 되돌아올 수 있게.
const _languages = [(Locale('ko'), '한국어'), (Locale('en'), 'English')];

Widget _themeIcon(ThemeMode mode) => ToolIcon(switch (mode) {
      ThemeMode.system => 'icons8-system-theme.svg',
      ThemeMode.light => 'icons8-light-theme.svg',
      ThemeMode.dark => 'icons8-dark-theme.svg',
    });

String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };

class ThemeMenuButton extends StatelessWidget {
  const ThemeMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.themeMenuTooltip,
      icon: const ToolIcon('icons8-system-theme.svg'),
      initialValue: settings.themeMode,
      onSelected: settings.setThemeMode,
      itemBuilder: (_) => [
        for (final mode in ThemeMode.values)
          CheckedPopupMenuItem(
            value: mode,
            checked: mode == settings.themeMode,
            child: Text(_themeLabel(l10n, mode)),
          ),
      ],
    );
  }
}

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final l10n = AppLocalizations.of(context);
    // PopupMenuButton can't carry null as a value, so '' stands for "system".
    final current = settings.locale?.languageCode ?? '';
    return PopupMenuButton<String>(
      tooltip: l10n.languageMenuTooltip,
      icon: const ToolIcon('icons8-language.svg'),
      initialValue: current,
      onSelected: (code) => settings.setLocale(code.isEmpty ? null : Locale(code)),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: '', checked: current.isEmpty, child: Text(l10n.languageSystem)),
        const PopupMenuDivider(),
        for (final (locale, name) in _languages)
          CheckedPopupMenuItem(
            value: locale.languageCode,
            checked: current == locale.languageCode,
            child: Text(name),
          ),
      ],
    );
  }
}

/// 모바일 설정 화면용.
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

/// 모바일 설정 화면용.
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
