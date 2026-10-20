import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../application/folder_preview.dart';
import '../../application/thumbnail_cache.dart';
import '../../application/thumbnail_generator.dart';
import '../../application/thumbnail_policy.dart';
import '../../application/thumbnail_source.dart';
import 'file_icon.dart';

/// 동시에 디코딩하는 썸네일 수를 제한하는 큐. 사진이 수천 장인 폴더를 열어도
/// UI 스레드가 밀리지 않게 한다. 화면에서 사라진 셀의 대기 요청은 취소된다.
class ThumbnailQueue {
  ThumbnailQueue({this.maxConcurrent = 4});

  static final ThumbnailQueue shared = ThumbnailQueue();

  final int maxConcurrent;
  int _running = 0;
  // 나중에 요청한 것(현재 화면에 가까운 것)을 먼저 처리한다.
  final ListQueue<ThumbnailTicket> _waiting = ListQueue();

  /// 슬롯을 요청한다. 반환된 티켓의 [ThumbnailTicket.granted]가 완료되면 로드를 시작하고,
  /// 끝나면 반드시 [release]를 호출한다. 대기 중에 [cancel]하면 슬롯을 쓰지 않는다.
  ThumbnailTicket acquire() {
    final ticket = ThumbnailTicket();
    if (_running < maxConcurrent) {
      _running++;
      ticket._grant();
    } else {
      _waiting.addLast(ticket);
    }
    return ticket;
  }

  void release(ThumbnailTicket ticket) {
    if (ticket._released || !ticket._holdsSlot) return;
    ticket._released = true;
    _running--;
    _pump();
  }

  void cancel(ThumbnailTicket ticket) {
    if (ticket._holdsSlot) {
      release(ticket);
    } else {
      _waiting.remove(ticket);
    }
  }

  void _pump() {
    while (_running < maxConcurrent && _waiting.isNotEmpty) {
      final next = _waiting.removeLast();
      _running++;
      next._grant();
    }
  }
}

class ThumbnailTicket {
  final Completer<void> _completer = Completer<void>();
  bool _holdsSlot = false;
  bool _released = false;

  Future<void> get granted => _completer.future;

  void _grant() {
    _holdsSlot = true;
    _completer.complete();
  }
}

/// 앱 전체가 공유하는 디스크 캐시.
final DiskThumbnailCache sharedThumbnailCache = DiskThumbnailCache();

/// 파일 썸네일. 만들 수 없거나 실패하면 [FileIcon]으로 대체한다.
class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({
    super.key,
    required this.path,
    required this.name,
    required this.kind,
    required this.extent,
    this.modifiedMs,
    this.sizeBytes,
    this.queue,
    this.cache,
    this.generator,
  });

  final String path;
  final String name;
  final ThumbnailKind? kind;
  final double extent;

  /// 디스크 캐시 키에 쓰인다 — 파일이 바뀌면 썸네일도 새로 만든다.
  final int? modifiedMs;
  final int? sizeBytes;
  final ThumbnailQueue? queue;
  final DiskThumbnailCache? cache;
  final ThumbnailGenerator? generator;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  ThumbnailTicket? _ticket;
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _text;
  double? _aspect;
  bool _ready = false;
  bool _failed = false;

  ThumbnailQueue get _queue => widget.queue ?? ThumbnailQueue.shared;
  DiskThumbnailCache get _cache => widget.cache ?? sharedThumbnailCache;
  ThumbnailGenerator get _generator =>
      widget.generator ?? ThumbnailGenerator.shared;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ThumbnailImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path ||
        old.kind != widget.kind ||
        old.extent != widget.extent ||
        old.modifiedMs != widget.modifiedMs) {
      _stop();
      _ready = false;
      _failed = false;
      _text = null;
      _aspect = null;
      _start();
    }
  }

  void _finish(ThumbnailTicket ticket, {bool failed = false}) {
    _queue.release(ticket);
    if (!mounted || _ticket != ticket) return;
    setState(() {
      if (failed) {
        _failed = true;
      } else {
        _ready = true;
      }
    });
  }

  Future<void> _start() async {
    final kind = widget.kind;
    if (kind == null) return;
    final ticket = _queue.acquire();
    _ticket = ticket;
    await ticket.granted;
    if (!mounted || _ticket != ticket) return;

    if (kind == ThumbnailKind.svg) {
      // SVG 파싱은 위젯이 비동기로 처리하므로 슬롯을 바로 돌려준다.
      _finish(ticket);
      return;
    }

    if (kind == ThumbnailKind.text) {
      try {
        final bytes = await File(widget.path)
            .openRead(0, 2048)
            .fold<List<int>>([], (a, b) => a..addAll(b));
        _text = utf8.decode(bytes, allowMalformed: true);
        _finish(ticket);
      } catch (_) {
        _finish(ticket, failed: true);
      }
      return;
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = await resolveThumbnailProvider(
      kind: kind,
      path: widget.path,
      modifiedMs: widget.modifiedMs,
      sizeBytes: widget.sizeBytes,
      px: (widget.extent * dpr).round(),
      cache: _cache,
      generator: _generator,
    );
    if (!mounted || _ticket != ticket) {
      _queue.release(ticket);
      return;
    }
    // 만들 수 없는 파일(앨범 아트 없음 등)은 아이콘으로 둔다.
    if (provider == null) {
      _finish(ticket, failed: true);
      return;
    }
    _provider = provider;
    final stream = provider.resolve(ImageConfiguration.empty);
    _stream = stream;
    _listener = ImageStreamListener(
      (info, sync) {
        _aspect = info.image.width / info.image.height;
        _finish(ticket);
      },
      onError: (error, stack) => _finish(ticket, failed: true),
    );
    stream.addListener(_listener!);
  }

  void _stop() {
    final ticket = _ticket;
    if (ticket != null) _queue.cancel(ticket);
    _ticket = null;
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
    _provider = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Widget _fallback() => ThumbnailIconTile(
    name: widget.name,
    isDirectory: false,
    extent: widget.extent,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.kind == null || _failed || !_ready) return _fallback();
    final radius = thumbnailRadius(widget.extent);
    switch (widget.kind!) {
      case ThumbnailKind.svg:
        // 벡터 그림은 비율과 여백이 제각각이라 타일 위에 놓는다.
        return ThumbnailIconTile(
          name: widget.name,
          isDirectory: false,
          extent: widget.extent,
          child: SvgPicture.file(
            File(widget.path),
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const SizedBox.shrink(),
          ),
        );
      case ThumbnailKind.text:
        return _TextPreview(text: _text ?? '', extent: widget.extent, radius: radius);
      case ThumbnailKind.raster:
      case ThumbnailKind.pdf:
      case ThumbnailKind.video:
      case ThumbnailKind.audio:
        // 비율을 알고 있으니 그 크기로 맞춘 뒤 모서리를 자른다 — 여백 없이 그림 자체가 둥글다.
        return Center(
          child: AspectRatio(
            aspectRatio: _aspect ?? 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Image(
                image: _provider!,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallback(),
              ),
            ),
          ),
        );
    }
  }
}

/// 썸네일 모서리 반지름 — 셀 크기에 비례해 작게/크게 어느 크기에서나 비슷해 보인다.
double thumbnailRadius(double extent) => (extent * 0.08).clamp(5.0, 14.0);

/// 아이콘(폴더, 내용 썸네일이 없는 파일)을 둥근 타일 위에 놓는다. [child]가 있으면 아이콘 대신 쓴다.
class ThumbnailIconTile extends StatelessWidget {
  const ThumbnailIconTile({
    super.key,
    required this.name,
    required this.isDirectory,
    required this.extent,
    this.child,
  });

  final String name;
  final bool isDirectory;
  final double extent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(thumbnailRadius(extent)),
      ),
      child: Center(
        child:
            child ??
            FileIcon(name: name, isDirectory: isDirectory, size: extent * 0.7),
      ),
    );
  }
}

/// 텍스트 파일의 앞부분을 작은 글씨로 보여 주는 종이 모양 미리보기.
class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text, required this.extent, required this.radius});

  final String text;
  final double extent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final lines = text.replaceAll('\r', '').split('\n').take(14).join('\n');
    return Center(
      child: AspectRatio(
        aspectRatio: 0.78,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: const EdgeInsets.all(5),
            color: const Color(0xFFF7F5EF),
            child: Text(
              lines,
              maxLines: 14,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: const TextStyle(fontSize: 6, height: 1.25, color: Color(0xFF2A2A2A)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 폴더 썸네일 — 폴더 안의 이미지를 최대 4장 모아 둥근 타일에 보여 준다. 이미지가 없거나 아직
/// 찾는 중이면 일반 폴더 아이콘 타일이다. 폴더임을 알 수 있게 모자이크 위에 작은 폴더 아이콘을 얹는다.
class FolderThumbnail extends StatefulWidget {
  const FolderThumbnail({
    super.key,
    required this.path,
    required this.name,
    required this.extent,
    this.modifiedMs,
    this.queue,
    this.cache,
    this.generator,
    this.finder,
  });

  final String path;
  final String name;
  final double extent;
  final int? modifiedMs;
  final ThumbnailQueue? queue;
  final DiskThumbnailCache? cache;
  final ThumbnailGenerator? generator;
  final FolderPreviewFinder? finder;

  @override
  State<FolderThumbnail> createState() => _FolderThumbnailState();
}

class _FolderThumbnailState extends State<FolderThumbnail> {
  ThumbnailTicket? _ticket;
  List<ImageProvider> _providers = const [];

  ThumbnailQueue get _queue => widget.queue ?? ThumbnailQueue.shared;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(FolderThumbnail old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.modifiedMs != widget.modifiedMs || old.extent != widget.extent) {
      _stop();
      _providers = const [];
      _start();
    }
  }

  Future<void> _start() async {
    final ticket = _queue.acquire();
    _ticket = ticket;
    await ticket.granted;
    if (!mounted || _ticket != ticket) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (widget.extent / 2 * dpr).round();
    try {
      final images = await (widget.finder ?? FolderPreviewFinder.shared).find(widget.path, widget.modifiedMs);
      final providers = <ImageProvider>[];
      for (final image in images) {
        final provider = await resolveThumbnailProvider(
          kind: ThumbnailKind.raster,
          path: image.path,
          modifiedMs: image.modifiedMs,
          sizeBytes: image.sizeBytes,
          px: px,
          cache: widget.cache ?? sharedThumbnailCache,
          generator: widget.generator ?? ThumbnailGenerator.shared,
        );
        if (provider != null) providers.add(provider);
        if (!mounted || _ticket != ticket) break;
      }
      if (mounted && _ticket == ticket) setState(() => _providers = providers);
    } catch (_) {}
    _queue.release(ticket);
  }

  void _stop() {
    final ticket = _ticket;
    if (ticket != null) _queue.cancel(ticket);
    _ticket = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_providers.isEmpty) {
      return ThumbnailIconTile(name: widget.name, isDirectory: true, extent: widget.extent);
    }
    final radius = thumbnailRadius(widget.extent);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget cell(int i) => i < _providers.length
        ? Image(image: _providers[i], fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox())
        : const SizedBox();
    final mosaic = _providers.length == 1
        ? cell(0)
        : Column(
            children: [
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cell(0)), const SizedBox(width: 1), Expanded(child: cell(1))])),
              const SizedBox(height: 1),
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cell(2)), const SizedBox(width: 1), Expanded(child: cell(3))])),
            ],
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black12,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: mosaic),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: FileIcon(name: widget.name, isDirectory: true, size: widget.extent * 0.3),
        ),
      ],
    );
  }
}
