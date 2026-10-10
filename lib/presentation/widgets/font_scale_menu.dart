import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/font_scale_provider.dart';
import 'tool_icon.dart';

/// 글자 크기: 앱 바 아이콘 → 체크 표시가 있는 팝업 메뉴 (테마·언어 메뉴와 같은 방식 —
/// 순환 버튼은 지금 상태와 다음 상태가 보이지 않는다, theming.md §3).
class FontScaleMenuButton extends ConsumerWidget {
  const FontScaleMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scale = ref.watch(fontScaleProvider);
    String label(double s) => switch (s) {
          0.9 => l10n.fontScaleSmall,
          1.15 => l10n.fontScaleLarge,
          _ => l10n.fontScaleNormal,
        };
    return PopupMenuButton<double>(
      tooltip: l10n.fontScaleMenuTooltip,
      icon: const ToolIcon('icons8-ocr.svg'),
      initialValue: scale,
      onSelected: ref.read(fontScaleProvider.notifier).setScale,
      itemBuilder: (_) => [
        for (final s in fontScaleChoices)
          CheckedPopupMenuItem(value: s, checked: s == scale, child: Text(label(s))),
      ],
    );
  }
}
