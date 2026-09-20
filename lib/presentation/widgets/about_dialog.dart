import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../application/usecases/open_url.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

const _openUrl = OpenUrl();
const _githubUrl = 'https://github.com/jejezz/daylight-commander-flutter';

/// 앱 정보(About) 다이얼로그. 버전은 [PackageInfo]로 실제 빌드에서 읽어와
/// pubspec.yaml과 어긋날 일이 없게 한다.
Future<void> showAboutInfoDialog(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = isDark ? AppColors.primary : AppColors.primaryDeep;

  final features = [
    l10n.aboutFeatureNavigation,
    l10n.aboutFeatureFileOps,
    l10n.aboutFeatureNetwork,
    l10n.aboutFeatureViewer,
    l10n.aboutFeatureSync,
    l10n.aboutFeatureLocaleTheme,
  ];

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.view_column_outlined, size: 22, color: accent),
          const SizedBox(width: 8),
          Text(l10n.aboutDialogTitle),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.aboutTagline, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                l10n.aboutVersionLabel('${packageInfo.version}+${packageInfo.buildNumber}'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Text(l10n.aboutDescription),
              const SizedBox(height: 16),
              Text(l10n.aboutFeaturesTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(l10n.aboutTechStackLabel, style: Theme.of(context).textTheme.bodySmall),
              Text(l10n.aboutLicenseLabel, style: Theme.of(context).textTheme.bodySmall),
              const Text('Copyright © 2026 jyahn', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _openUrl(_githubUrl),
          child: Text(l10n.aboutGithubButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}
