import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'about_dialog.dart';

/// Daylight Commander 의 정보 창 문구. 공통 about_dialog.dart 는 템플릿과 같게 두고,
/// 앱마다 다른 부분만 여기서 넘긴다 (conventions/about-dialog.md §3).
Future<void> showDaylightAbout(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppAboutDialog(
    context,
    tagline: l10n.aboutTagline,
    description: l10n.aboutDescription,
    features: [
      l10n.aboutFeatureNavigation,
      l10n.aboutFeatureFileOps,
      l10n.aboutFeatureNetwork,
      l10n.aboutFeatureViewer,
      l10n.aboutFeatureSync,
      l10n.aboutFeatureLocaleTheme,
    ],
  );
}
