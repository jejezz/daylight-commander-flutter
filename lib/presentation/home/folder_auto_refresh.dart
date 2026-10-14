import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pane_controller.dart';

/// 앱이 활성화(포커스)되어 있는 동안만 두 패널의 폴더를 [interval]마다 조용히 다시 읽는다.
/// 포커스를 되찾으면 바로 한 번 읽고, 잃으면 멈춘다. 로컬·네트워크 드라이브만 읽고
/// FTP/SFTP/WebDAV 패널은 건드리지 않는다 ([PaneController.refreshQuietly]).
class FolderAutoRefresh extends ConsumerStatefulWidget {
  const FolderAutoRefresh({super.key, required this.child, this.interval = const Duration(seconds: 5)});

  final Widget child;
  final Duration interval;

  @override
  ConsumerState<FolderAutoRefresh> createState() => _FolderAutoRefreshState();
}

class _FolderAutoRefreshState extends ConsumerState<FolderAutoRefresh> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onState);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _start(refreshNow: false);
  }

  void _onState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start(refreshNow: true);
    } else {
      _stop();
    }
  }

  void _start({required bool refreshNow}) {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _refresh());
    if (refreshNow) _refresh();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _refresh() {
    for (final side in PaneSide.values) {
      unawaited(ref.read(paneControllerProvider(side).notifier).refreshQuietly());
    }
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
