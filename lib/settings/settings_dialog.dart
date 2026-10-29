// 설정 창 — 왼쪽에서 구역을 고르고 오른쪽에서 바꾼다. 바꾼 값은 바로 적용되고 저장된다.
// daylight-workbench의 설정 창(lib/ui/settings_dialog.dart)을 따랐다.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'settings_menus.dart';

enum SettingsSection {
  appearance(Icons.palette_outlined),
  language(Icons.language);

  const SettingsSection(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
        appearance => l10n.settingsSectionAppearance,
        language => l10n.settingsSectionLanguage,
      };
}

Future<void> showSettingsDialog(BuildContext context, {SettingsSection initial = SettingsSection.appearance}) {
  return showDialog<void>(context: context, builder: (_) => SettingsDialog(initial: initial));
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, this.initial = SettingsSection.appearance});

  final SettingsSection initial;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SettingsSection _section = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsTitle),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 24, 0),
      content: SizedBox(
        width: 640,
        height: 380,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: ListView(
                children: [
                  for (final s in SettingsSection.values)
                    _SectionTile(
                      selected: s == _section,
                      icon: s.icon,
                      label: s.label(l10n),
                      onTap: () => setState(() => _section = s),
                    ),
                ],
              ),
            ),
            const VerticalDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, bottom: 16),
                child: switch (_section) {
                  SettingsSection.appearance => const _AppearanceSection(),
                  SettingsSection.language => const _LanguageSection(),
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose))],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// 고른 구역은 배경을 채우는 대신 왼쪽에 굵은 선을 그어 표시한다 — 고대비 테마에서도 글자가 읽힌다.
class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.selected, required this.icon, required this.label, required this.onTap});

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          // 선택 안 됐을 때도 같은 폭을 비워 둬서, 고를 때 글자가 옆으로 밀리지 않게 한다.
          border: Border(left: BorderSide(width: 3, color: selected ? scheme.primary : Colors.transparent)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(color: selected ? scheme.onSurface : color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l10n.settingsBrightness),
        const ThemeSegmentedButton(),
        _Heading(l10n.settingsPalette),
        const PaletteChoice(),
        _Heading(l10n.settingsFontSize),
        const FontScaleSegmentedButton(),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_Heading(l10n.settingsLanguage), const LanguageSegmentedButton()],
    );
  }
}
