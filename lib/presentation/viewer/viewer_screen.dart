import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../application/usecases/open_with_default_app.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'video_host.dart';

const _openWithDefaultApp = OpenWithDefaultApp();

const _textExtensions = {
  'txt', 'md', 'json', 'xml', 'html', 'htm', 'css', 'java', 'dart', 'py', 'js',
  'ts', 'yaml', 'yml', 'sql', 'sh', 'log', 'ini', 'csv', 'c', 'cpp', 'h', 'kt',
  'swift', 'gradle',
  // 빌드·설정·스크립트·소스 등 순수 텍스트가 확실한 확장자.
  'mk', 'mak', 'bp', 'cmake', 'bzl', 'bazel', 'ninja', 'toml', 'cfg', 'conf',
  'properties', 'env', 'rc', 'cc', 'cxx', 'hpp', 'hh', 'hxx', 'm', 'mm', 'go',
  'rs', 'rb', 'php', 'pl', 'pm', 'lua', 'r', 'scala', 'groovy', 'cs', 'vb',
  'bat', 'cmd', 'ps1', 'psm1', 'bash', 'zsh', 'fish', 'jsx', 'tsx', 'mjs',
  'cjs', 'vue', 'svelte', 'scss', 'sass', 'less', 'svg', 'xsd', 'xsl', 'xslt',
  'plist', 'rst', 'adoc', 'tex', 'bib', 'tsv', 'diff', 'patch', 'aidl', 'hal',
  'proto', 'thrift', 'graphql', 'gql', 'tf', 'tfvars', 'gitignore',
  'gitattributes', 'editorconfig', 'dockerignore', 'lock', 'sln', 'csproj',
  'vcxproj', 'pro', 'pri', 'qml', 'asm', 's', 'ld', 'dts', 'dtsi', 'rules',
  'service', 'desktop', 'srt', 'vtt', 'ass', 'arb', 'pubspec',
};

/// 확장자가 없거나 흔한 이름의 순수 텍스트 파일 (소문자 비교).
const _textFileNames = {
  'makefile', 'gnumakefile', 'dockerfile', 'readme', 'license', 'licence',
  'changelog', 'authors', 'contributing', 'notice', 'copying', 'todo',
  'cmakelists.txt', 'gemfile', 'rakefile', 'procfile', 'vagrantfile',
  'jenkinsfile', 'build', 'workspace', 'owners', 'codeowners',
};

/// 앞부분 [head]만 보고 텍스트인지 추정한다. NUL 바이트가 있거나 제어 문자가
/// 많으면 바이너리, 아니면 텍스트(UTF-8이 아니어도 포함)로 본다.
bool looksLikeText(List<int> head) {
  if (head.isEmpty) return true;
  var control = 0;
  for (final b in head) {
    if (b == 0) return false;
    // 탭·개행·FF·ESC 는 텍스트에 흔하다.
    if (b < 0x20 && b != 9 && b != 10 && b != 13 && b != 12 && b != 27) {
      control++;
    }
  }
  return control * 100 < head.length * 5;
}
const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
const _pdfExtensions = {'pdf'};
const _videoExtensions = {'mp4', 'mov', 'mkv', 'avi', 'webm', 'm4v'};
const _audioExtensions = {'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'wma'};

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

/// 자체 뷰어 (F3). 텍스트/이미지/PDF/오디오/비디오/Hex를 지원하고, 그 외
/// 형식은 OS 기본 앱으로 열도록 안내한다.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.path, required this.name});

  final String path;
  final String name;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  bool _showHex = false;

  @override
  Widget build(BuildContext context) {
    final ext = _extensionOf(widget.name);
    final Widget body;
    if (_showHex) {
      body = _HexViewer(path: widget.path);
    } else if (_imageExtensions.contains(ext)) {
      body = _ImageViewer(path: widget.path);
    } else if (_textExtensions.contains(ext) ||
        _textFileNames.contains(widget.name.toLowerCase())) {
      body = _TextViewer(path: widget.path);
    } else if (_pdfExtensions.contains(ext)) {
      body = _PdfViewer(path: widget.path);
    } else if (_videoExtensions.contains(ext)) {
      body = _VideoViewer(path: widget.path);
    } else if (_audioExtensions.contains(ext)) {
      body = _AudioViewer(path: widget.path, name: widget.name);
    } else {
      // 모르는 형식은 내용을 살펴 텍스트면 텍스트 뷰어로 연다.
      body = _SniffingViewer(path: widget.path);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: Icon(_showHex ? Icons.description_outlined : Icons.memory),
            tooltip: _showHex
                ? AppLocalizations.of(context).normalView
                : AppLocalizations.of(context).hexView,
            onPressed: () => setState(() => _showHex = !_showHex),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 8,
      child: Center(
        child: Image.file(
          File(path),
          errorBuilder: (context, error, stack) =>
              Text(AppLocalizations.of(context).imageLoadError('$error')),
        ),
      ),
    );
  }
}

class _PdfViewer extends StatelessWidget {
  const _PdfViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(path);
  }
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.path});

  final String path;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  @override
  Widget build(BuildContext context) {
    // 동영상 층은 Navigator 위에 있어서, 뒤로 가는 전환 동안(Route 가 dispose 되기 전까지)
    // 계속 탐색기를 가린다. 뒤로 가기가 시작되면 바로 멈추고 숨긴다.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) VideoHost.instance.close();
      },
      child: VideoSlot(path: widget.path),
    );
  }
}

class _AudioViewer extends StatefulWidget {
  const _AudioViewer({required this.path, required this.name});

  final String path;
  final String name;

  @override
  State<_AudioViewer> createState() => _AudioViewerState();
}

class _AudioViewerState extends State<_AudioViewer> {
  late final Player _player;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _player.open(Media(Uri.file(widget.path).toString()));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack, size: 64),
              const SizedBox(height: 16),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              StreamBuilder<Duration>(
                stream: _player.stream.duration,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final maxMs = duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1.0;
                  return StreamBuilder<Duration>(
                    stream: _player.stream.position,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;
                      final value = position.inMilliseconds
                          .clamp(0, maxMs.toInt())
                          .toDouble();
                      return Column(
                        children: [
                          Slider(
                            value: value,
                            max: maxMs,
                            onChanged: (v) =>
                                _player.seek(Duration(milliseconds: v.toInt())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_format(position)),
                              Text(_format(duration)),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return IconButton(
                    iconSize: 48,
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    ),
                    onPressed: () => _player.playOrPause(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextViewer extends StatefulWidget {
  const _TextViewer({required this.path});

  final String path;

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        // 인코딩 자동 감지는 아직 없음(P2) — UTF-8 실패 시 Latin-1로 폴백.
        text = latin1.decode(bytes);
      }
      if (mounted) setState(() => _content = text);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (_content == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content!,
        style: AppFonts.mono.copyWith(fontSize: 13),
      ),
    );
  }
}

class _HexViewer extends StatefulWidget {
  const _HexViewer({required this.path});

  final String path;

  @override
  State<_HexViewer> createState() => _HexViewerState();
}

class _HexViewerState extends State<_HexViewer> {
  // 큰 파일 전체를 메모리에 올리지 않도록 미리보기 상한을 둔다 (스트리밍은 P2 후순위).
  static const _maxBytes = 262144;

  Uint8List? _bytes;
  bool _truncated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.path);
      final length = await file.length();
      final raf = await file.open();
      final readLen = length > _maxBytes ? _maxBytes : length;
      final bytes = await raf.read(readLen);
      await raf.close();
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _truncated = length > _maxBytes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    final bytes = _bytes;
    if (bytes == null) return const Center(child: CircularProgressIndicator());

    final rowCount = (bytes.length / 16).ceil();
    return Column(
      children: [
        if (_truncated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context).hexTruncatedNote(_maxBytes ~/ 1024),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: rowCount,
            itemBuilder: (context, index) {
              final start = index * 16;
              final end = (start + 16 > bytes.length) ? bytes.length : start + 16;
              final rowBytes = bytes.sublist(start, end);
              final offset = start.toRadixString(16).padLeft(8, '0');
              final hex = rowBytes
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ')
                  .padRight(47);
              final ascii = String.fromCharCodes(
                rowBytes.map((b) => (b >= 0x20 && b < 0x7f) ? b : 0x2e),
              );
              return Text(
                '$offset  $hex  $ascii',
                style: AppFonts.mono.copyWith(fontSize: 12),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 확장자로 알 수 없는 파일의 앞 8KB를 읽어 텍스트면 [_TextViewer], 아니면
/// [_UnsupportedViewer]를 보여준다.
class _SniffingViewer extends StatefulWidget {
  const _SniffingViewer({required this.path});

  final String path;

  @override
  State<_SniffingViewer> createState() => _SniffingViewerState();
}

class _SniffingViewerState extends State<_SniffingViewer> {
  late final Future<bool> _isText = _sniff();

  Future<bool> _sniff() async {
    try {
      final raf = await File(widget.path).open();
      try {
        return looksLikeText(await raf.read(8192));
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isText,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.data!
            ? _TextViewer(path: widget.path)
            : _UnsupportedViewer(path: widget.path);
      },
    );
  }
}

class _UnsupportedViewer extends StatelessWidget {
  const _UnsupportedViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.unsupportedFormat),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openWithDefaultApp(path),
            child: Text(l10n.openWithDefaultAppButton),
          ),
        ],
      ),
    );
  }
}
