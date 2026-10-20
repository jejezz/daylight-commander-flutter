import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfrx/pdfrx.dart';

import 'thumbnail_policy.dart';

/// [ThumbnailKind]별로 파일에서 [extent]px 이하의 PNG 썸네일을 만든다. 만들 수 없으면 null.
///
/// 이미지 디코딩과 축소는 엔진의 코덱이 UI 스레드 밖에서 하고, PDF는 pdfrx의 작업 isolate,
/// 오디오 태그 파싱은 별도 isolate에서 돈다. 호출하는 쪽은 동시 실행 수만 제한하면 된다.
class ThumbnailGenerator {
  ThumbnailGenerator._();

  static final ThumbnailGenerator shared = ThumbnailGenerator._();

  // libmpv 인스턴스는 무거워서 비디오 썸네일은 한 번에 하나씩 만든다.
  Future<void> _videoTail = Future.value();

  Future<Uint8List?> generate(
    ThumbnailKind kind,
    String path,
    int extent,
  ) async {
    try {
      return switch (kind) {
        ThumbnailKind.raster => await _fromFile(path, extent),
        ThumbnailKind.pdf => await _fromPdf(path, extent),
        ThumbnailKind.audio => await _fromAudio(path, extent),
        ThumbnailKind.video => await _fromVideo(path, extent),
        ThumbnailKind.svg || ThumbnailKind.text => null,
      };
    } catch (e, st) {
      debugPrint('thumbnail($kind) $path: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> _fromFile(String path, int extent) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    return _scaledPng(buffer, extent);
  }

  Future<Uint8List?> _fromPdf(String path, int extent) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openFile(path);
    try {
      if (document.pages.isEmpty) return null;
      final page = document.pages.first;
      final scale =
          extent / (page.width > page.height ? page.width : page.height);
      final image = await page.render(
        width: (page.width * scale).round().clamp(1, extent),
        height: (page.height * scale).round().clamp(1, extent),
        backgroundColor: 0xFFFFFFFF,
      );
      if (image == null) return null;
      try {
        final decoded = await image.createImage();
        try {
          final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
          return data?.buffer.asUint8List();
        } finally {
          decoded.dispose();
        }
      } finally {
        image.dispose();
      }
    } finally {
      await document.dispose();
    }
  }

  Future<Uint8List?> _fromAudio(String path, int extent) async {
    final art = await Isolate.run(() {
      final metadata = readMetadata(File(path), getImage: true);
      return metadata.pictures.isEmpty
          ? null
          : Uint8List.fromList(metadata.pictures.first.bytes);
    });
    if (art == null || art.isEmpty) return null;
    return _scaledPng(await ui.ImmutableBuffer.fromUint8List(art), extent);
  }

  Future<Uint8List?> _fromVideo(String path, int extent) {
    final completer = Completer<Uint8List?>();
    _videoTail = _videoTail.then((_) async {
      try {
        completer.complete(await _videoFrame(path, extent));
      } catch (e, st) {
        debugPrint('video thumbnail $path: $e\n$st');
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<Uint8List?> _videoFrame(String path, int extent) async {
    final player = Player();
    try {
      await player.setVolume(0);
      // 화면에 그리지 않아도 VideoController가 붙어 있어야 libmpv가 영상을 디코딩해 프레임을 낸다
      // (vo=null 로는 재생이 시작되지 않고 버퍼링에서 멈춘다).
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false),
      );
      await player.open(Media(Uri.file(path).toString()));
      await controller.waitUntilFirstFrameRendered.timeout(const Duration(seconds: 8));
      final duration = player.state.duration;
      if (duration > const Duration(seconds: 2)) {
        // 첫 프레임은 검은 화면인 경우가 많아 전체의 10% 지점을 쓴다(최대 10초).
        final target = Duration(milliseconds: (duration.inMilliseconds * 0.1).round().clamp(0, 10000));
        await player.seek(target);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      await player.pause();
      final png = await player.screenshot(format: 'image/png');
      if (png == null || png.isEmpty) return null;
      return await _scaledPng(await ui.ImmutableBuffer.fromUint8List(png), extent);
    } finally {
      await player.dispose();
    }
  }

  /// [buffer]의 이미지를 긴 변이 [extent] 이하가 되도록 줄여 PNG로 인코딩한다.
  Future<Uint8List?> _scaledPng(ui.ImmutableBuffer buffer, int extent) async {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = longest > extent ? extent / longest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, extent),
        targetHeight: (descriptor.height * scale).round().clamp(1, extent),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          return data?.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
