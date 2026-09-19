import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/operation_controller.dart';
import '../theme/app_theme.dart';

const _kindLabel = {
  OperationKind.copy: '복사 중',
  OperationKind.move: '이동 중',
  OperationKind.delete: '삭제 중',
};

class OperationBanner extends ConsumerWidget {
  const OperationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operation = ref.watch(operationControllerProvider);
    if (operation == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percent = (operation.ratio * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceHi : AppColors.surfaceHiLight,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  operation.error ??
                      '${_kindLabel[operation.kind]} · ${operation.currentName} ($percent%)',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: operation.error == null ? operation.ratio : 0,
                    minHeight: 4,
                    color: operation.error != null
                        ? AppColors.danger
                        : (isDark ? AppColors.primary : AppColors.primaryDeep),
                  ),
                ),
              ],
            ),
          ),
          if (operation.error == null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '취소',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => ref.read(operationControllerProvider.notifier).cancel(),
            ),
          ],
        ],
      ),
    );
  }
}
