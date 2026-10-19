import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../application/thumbnail_policy.dart';
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

/// 파일 썸네일. 만들 수 없거나 실패하면 [FileIcon]으로 대체한다.
class ThumbnailImage extends StatefulWidget {
  const ThumbnailImage({
    super.key,
    required this.path,
    required this.name,
    required this.kind,
    required this.extent,
    this.queue,
  });

  final String path;
  final String name;
  final ThumbnailKind? kind;
  final double extent;
  final ThumbnailQueue? queue;

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  ThumbnailTicket? _ticket;
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _ready = false;
  bool _failed = false;

  ThumbnailQueue get _queue => widget.queue ?? ThumbnailQueue.shared;

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
        old.extent != widget.extent) {
      _stop();
      _ready = false;
      _failed = false;
      _start();
    }
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
      _queue.release(ticket);
      setState(() => _ready = true);
      return;
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = ResizeImage(
      FileImage(File(widget.path)),
      width: (widget.extent * dpr).round(),
      allowUpscaling: false,
    );
    _provider = provider;
    final stream = provider.resolve(ImageConfiguration.empty);
    _stream = stream;
    _listener = ImageStreamListener(
      (info, sync) {
        _queue.release(ticket);
        if (mounted) setState(() => _ready = true);
      },
      onError: (error, stack) {
        _queue.release(ticket);
        if (mounted) setState(() => _failed = true);
      },
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

  Widget _icon() => FileIcon(
    name: widget.name,
    isDirectory: false,
    size: widget.extent * 0.7,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.kind == null || _failed || !_ready) {
      return Center(child: _icon());
    }
    if (widget.kind == ThumbnailKind.svg) {
      return SvgPicture.file(
        File(widget.path),
        width: widget.extent,
        height: widget.extent,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => Center(child: _icon()),
      );
    }
    return Image(
      image: _provider!,
      fit: BoxFit.contain,
      width: widget.extent,
      height: widget.extent,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Center(child: _icon()),
    );
  }
}
