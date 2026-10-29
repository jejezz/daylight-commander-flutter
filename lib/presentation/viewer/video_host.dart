import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 앱 수명 동안 하나만 유지하는 동영상 출력.
///
/// `Video` 위젯(Texture)을 열 때마다 붙였다 떼면 Windows 에서 엔진의 텍스처 처리 중
/// flutter_windows.dll 이 비정상 종료된다. 그래서 위젯은 앱 최상단에 항상 두고,
/// 뷰어가 열려 있을 때만 [VideoSlot] 이 알려 주는 영역으로 옮겨 보여 준다.
class VideoHost {
  VideoHost._();

  static final VideoHost instance = VideoHost._();

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  /// 화면 전역 좌표의 표시 영역. null 이면 숨김(화면 밖 1x1 로 유지).
  final ValueNotifier<Rect?> rect = ValueNotifier<Rect?>(null);

  void open(String path) {
    player.open(Media(Uri.file(path).toString()));
  }

  void close() {
    player.stop().catchError((_) {});
    rect.value = null;
  }
}

/// 앱 최상단에서 [VideoHost] 의 `Video` 를 항상 유지하는 층.
class VideoHostLayer extends StatefulWidget {
  const VideoHostLayer({super.key, required this.child});

  final Widget child;

  @override
  State<VideoHostLayer> createState() => _VideoHostLayerState();
}

class _VideoHostLayerState extends State<VideoHostLayer> {
  final _stackKey = GlobalKey();

  // 컨트롤(툴팁 등)이 Overlay 를 요구하지만 이 층은 Navigator 밖이라 자체 Overlay 를 둔다.
  // 전체 화면 버튼·단축키는 Navigator 를 요구하므로 뺀다.
  late final OverlayEntry _videoEntry = OverlayEntry(
    builder: (context) {
      final player = VideoHost.instance.player;
      return MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          bottomButtonBar: const [
            MaterialDesktopPlayOrPauseButton(),
            MaterialDesktopVolumeButton(),
            MaterialDesktopPositionIndicator(),
          ],
          keyboardShortcuts: {
            const SingleActivator(LogicalKeyboardKey.space): player.playOrPause,
          },
        ),
        fullscreen: const MaterialDesktopVideoControlsThemeData(),
        child: Video(controller: VideoHost.instance.controller),
      );
    },
  );

  Rect _toLocal(Rect global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return global;
    return box.globalToLocal(global.topLeft) & global.size;
  }

  @override
  Widget build(BuildContext context) {
    final host = VideoHost.instance;
    return Stack(
      key: _stackKey,
      children: [
        Positioned.fill(child: widget.child),
        ValueListenableBuilder<Rect?>(
          valueListenable: host.rect,
          builder: (context, rect, _) {
            final shown = rect != null;
            final r = shown ? _toLocal(rect) : const Rect.fromLTWH(-4, -4, 1, 1);
            return Positioned.fromRect(
              rect: r,
              child: IgnorePointer(
                ignoring: !shown,
                // Opacity 0 은 자식을 그리지 않아 텍스처 레이어가 빠지므로, 숨길 때는
                // 화면 밖의 1x1 로 두고 계속 그린다.
                child: Overlay(initialEntries: [_videoEntry]),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 뷰어 화면에서 동영상이 표시될 자리. 영역을 [VideoHost] 에 알린다.
class VideoSlot extends StatefulWidget {
  const VideoSlot({super.key, required this.path});

  final String path;

  @override
  State<VideoSlot> createState() => _VideoSlotState();
}

class _VideoSlotState extends State<VideoSlot> {
  @override
  void initState() {
    super.initState();
    VideoHost.instance.open(widget.path);
  }

  @override
  void dispose() {
    VideoHost.instance.close();
    super.dispose();
  }

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (VideoHost.instance.rect.value != rect) {
      VideoHost.instance.rect.value = rect;
    }
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _report());
    return const SizedBox.expand();
  }
}
