import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ftp_session_manager.dart';
import '../../application/usecases/list_ftp_directory.dart';
import '../../application/usecases/list_local_directory.dart';
import '../../domain/entities/file_entry.dart';

enum PaneSide { left, right }

PaneSide otherSide(PaneSide side) => side == PaneSide.left ? PaneSide.right : PaneSide.left;

bool isFtpPath(String path) => path.startsWith('ftp://');

/// [path]가 `ftp://`로 시작하면 그대로 파싱하고, 아니면 로컬 파일 경로로 본다.
/// PaneState.currentPath는 계속 String이지만, 이 헬퍼로 언제든 두 스킴을
/// 구분해 다룰 수 있다 (ARCHITECTURE.md 4장 — 최소 변경으로 FTP 스킴 추가).
Uri resolveLocationString(String path) => isFtpPath(path) ? Uri.parse(path) : Uri.file(path);

/// [location]을 다시 패널 경로 문자열로 되돌린다 (로컬은 파일 경로, FTP는
/// URI 문자열 그대로).
String locationToPathString(Uri location) =>
    location.scheme == 'file' ? location.toFilePath() : location.toString();

enum SortField { name, size, modified, extension }

/// `copyWith`에서 "안 넘김"과 "명시적으로 null"을 구분하기 위한 센티널.
const _unset = Object();

class PaneState {
  /// `visibleEntries`/`selectedEntries`는 예전엔 접근할 때마다 다시 필터링하는
  /// getter였다 — 선택(클릭) 한 번에 PaneController/PaneView/F-바/상태바가 각자
  /// 다시 계산을 트리거해서 같은 리스트를 3~4번 필터링했다. 파일이 많은
  /// 폴더에서는 이 중복 계산이 선택 하이라이트가 그려지기 전에 프레임을
  /// 지연시킬 만큼 쌓였다. 팩토리 생성자에서 상태가 바뀔 때 딱 한 번만
  /// 계산해서 필드로 들고 있는 식으로 고쳤다 (사용자 피드백으로 발견).
  factory PaneState({
    required String currentPath,
    List<FileEntry> entries = const [],
    bool loading = false,
    String? error,
    Set<Uri> selection = const {},
    int? cursorIndex,
    List<String> backHistory = const [],
    List<String> forwardHistory = const [],
    SortField sortField = SortField.name,
    bool sortAscending = true,
    bool showHidden = false,
    String quickFilter = '',
  }) {
    final visible = _filterVisible(entries, showHidden, quickFilter);
    return PaneState._(
      currentPath: currentPath,
      entries: entries,
      loading: loading,
      error: error,
      selection: selection,
      cursorIndex: cursorIndex,
      backHistory: backHistory,
      forwardHistory: forwardHistory,
      sortField: sortField,
      sortAscending: sortAscending,
      showHidden: showHidden,
      quickFilter: quickFilter,
      visibleEntries: visible,
      selectedEntries: visible.where((e) => selection.contains(e.location)).toList(),
    );
  }

  const PaneState._({
    required this.currentPath,
    required this.entries,
    required this.loading,
    required this.error,
    required this.selection,
    required this.cursorIndex,
    required this.backHistory,
    required this.forwardHistory,
    required this.sortField,
    required this.sortAscending,
    required this.showHidden,
    required this.quickFilter,
    required this.visibleEntries,
    required this.selectedEntries,
  });

  final String currentPath;
  final List<FileEntry> entries;
  final bool loading;
  final String? error;
  final Set<Uri> selection;

  /// 키보드 커서(위/아래 화살표) 위치이자 Shift+클릭 범위선택의 기준점.
  /// 클릭·화살표 이동 시 갱신되며, 반드시 [selection]에 포함돼 있는 건 아니다
  /// (화살표만으로 이동한 커서는 스페이스를 눌러야 "진짜" 선택에 들어간다).
  final int? cursorIndex;
  final List<String> backHistory;
  final List<String> forwardHistory;
  final SortField sortField;
  final bool sortAscending;
  final bool showHidden;
  final String quickFilter;

  /// 숨김파일 토글 + 퀵서치 필터가 반영된, 실제로 화면에 그려지는 목록.
  /// 선택/범위선택의 인덱스는 전부 이 리스트 기준이어야 한다.
  final List<FileEntry> visibleEntries;

  final List<FileEntry> selectedEntries;

  int get selectedTotalBytes => selectedEntries
      .where((e) => !e.isDirectory)
      .fold(0, (sum, e) => sum + (e.sizeBytes ?? 0));

  static List<FileEntry> _filterVisible(
    List<FileEntry> entries,
    bool showHidden,
    String quickFilter,
  ) {
    var result = showHidden ? entries : entries.where((e) => !e.isHidden);
    if (quickFilter.isNotEmpty) {
      final q = quickFilter.toLowerCase();
      result = result.where((e) => e.name.toLowerCase().contains(q));
    }
    return result.toList();
  }

  // `cursorIndex`는 명시적으로 null을 넣어서 "커서 해제"를 표현해야 할 때가
  // 있는데(`int? cursorIndex` + `??` 패턴으로는 "안 넘김"과 "null을 넘김"을
  // 구분할 수 없어 실제로는 절대 지워지지 않는 버그가 있었다), 이 센티널로
  // 둘을 구분한다.
  PaneState copyWith({
    String? currentPath,
    List<FileEntry>? entries,
    bool? loading,
    String? error,
    Set<Uri>? selection,
    Object? cursorIndex = _unset,
    List<String>? backHistory,
    List<String>? forwardHistory,
    SortField? sortField,
    bool? sortAscending,
    bool? showHidden,
    String? quickFilter,
  }) {
    return PaneState(
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      error: error,
      selection: selection ?? this.selection,
      cursorIndex:
          identical(cursorIndex, _unset) ? this.cursorIndex : cursorIndex as int?,
      backHistory: backHistory ?? this.backHistory,
      forwardHistory: forwardHistory ?? this.forwardHistory,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      showHidden: showHidden ?? this.showHidden,
      quickFilter: quickFilter ?? this.quickFilter,
    );
  }
}

List<FileEntry> _sorted(List<FileEntry> entries, SortField field, bool ascending) {
  final sorted = [...entries];
  int compare(FileEntry a, FileEntry b) {
    switch (field) {
      case SortField.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortField.size:
        return (a.sizeBytes ?? -1).compareTo(b.sizeBytes ?? -1);
      case SortField.modified:
        final am = a.modifiedAt;
        final bm = b.modifiedAt;
        if (am == null || bm == null) return 0;
        return am.compareTo(bm);
      case SortField.extension:
        String ext(FileEntry e) {
          final dot = e.name.lastIndexOf('.');
          return dot <= 0 ? '' : e.name.substring(dot + 1).toLowerCase();
        }
        return ext(a).compareTo(ext(b));
    }
  }

  sorted.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    final result = compare(a, b);
    return ascending ? result : -result;
  });
  return sorted;
}

RegExp _globToRegExp(String pattern) {
  final buffer = StringBuffer('^');
  for (final ch in pattern.split('')) {
    switch (ch) {
      case '*':
        buffer.write('.*');
      case '?':
        buffer.write('.');
      case '.':
        buffer.write(r'\.');
      default:
        buffer.write(RegExp.escape(ch));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false);
}

class PaneController extends StateNotifier<PaneState> {
  PaneController(String initialPath, this._ftpSessions)
      : super(PaneState(currentPath: initialPath)) {
    _load(initialPath, backHistory: const [], forwardHistory: const []);
  }

  final _listDirectory = const ListLocalDirectory();
  final FtpSessionManager _ftpSessions;

  DateTime? _lastTapAt;
  Uri? _lastTapLocation;

  /// 같은 항목을 [_doubleClickWindow] 안에 두 번 클릭했는지 직접 판정한다.
  ///
  /// `InkWell`에 `onTap`과 `onDoubleTap`을 같이 달면 Flutter가 더블탭 여부를
  /// 가리려고 ~300ms(`kDoubleTapTimeout`)를 기다린 뒤에야 `onTap`을 실행해서
  /// 선택 자체가 한 템포 늦게 반응한다 (사용자가 두 번째로 지적한 "여전히
  /// 느리다"의 실제 원인 — 첫 번째 memoization 수정은 별개의 진짜 비효율이긴
  /// 했지만 이 지연의 주범은 아니었다). `onDoubleTap`을 없애고 이 타이머로
  /// 더블클릭을 직접 감지하면 단일 클릭 선택은 즉시 반응한다.
  static const _doubleClickWindow = Duration(milliseconds: 350);

  bool consumeDoubleClick(Uri location) {
    final now = DateTime.now();
    final isDouble = _lastTapLocation == location &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) < _doubleClickWindow;
    _lastTapAt = now;
    _lastTapLocation = location;
    return isDouble;
  }

  Future<void> _load(
    String path, {
    required List<String> backHistory,
    required List<String> forwardHistory,
  }) async {
    state = state.copyWith(
      loading: true,
      error: null,
      selection: const {},
      cursorIndex: null,
      quickFilter: '',
    );
    try {
      final entries = isFtpPath(path)
          ? await ListFtpDirectory(_ftpSessions)(Uri.parse(path))
          : await _listDirectory(path);
      state = state.copyWith(
        currentPath: path,
        entries: _sorted(entries, state.sortField, state.sortAscending),
        loading: false,
        backHistory: backHistory,
        forwardHistory: forwardHistory,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> navigateTo(String path) async {
    if (path == state.currentPath) return;
    await _load(
      path,
      backHistory: [...state.backHistory, state.currentPath],
      forwardHistory: const [],
    );
  }

  Future<void> goBack() async {
    if (state.backHistory.isEmpty) return;
    final newBack = [...state.backHistory];
    final previous = newBack.removeLast();
    await _load(
      previous,
      backHistory: newBack,
      forwardHistory: [state.currentPath, ...state.forwardHistory],
    );
  }

  Future<void> goForward() async {
    if (state.forwardHistory.isEmpty) return;
    final newForward = [...state.forwardHistory];
    final next = newForward.removeAt(0);
    await _load(
      next,
      backHistory: [...state.backHistory, state.currentPath],
      forwardHistory: newForward,
    );
  }

  Future<void> refresh() async {
    final path = state.currentPath;
    final entries = isFtpPath(path)
        ? await ListFtpDirectory(_ftpSessions)(Uri.parse(path))
        : await _listDirectory(path);
    final validPaths = entries.map((e) => e.location).toSet();
    final sorted = _sorted(entries, state.sortField, state.sortAscending);
    final visibleCount =
        PaneState._filterVisible(sorted, state.showHidden, state.quickFilter).length;
    final cursor = state.cursorIndex;
    state = state.copyWith(
      entries: sorted,
      selection: state.selection.intersection(validPaths),
      // 새로고침 중 항목이 지워지는 등으로 개수가 줄면 커서가 범위를 벗어날 수
      // 있어 안전하게 clamp하거나, 목록이 비면 아예 커서를 없앤다.
      cursorIndex: visibleCount == 0 ? null : cursor?.clamp(0, visibleCount - 1),
    );
  }

  void openEntry(FileEntry entry) {
    if (entry.isDirectory) {
      navigateTo(locationToPathString(entry.location));
    }
  }

  void goUp() {
    if (isFtpPath(state.currentPath)) {
      final uri = Uri.parse(state.currentPath);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return; // 이미 루트
      segments.removeLast();
      final parentPath = segments.isEmpty ? '/' : '/${segments.join('/')}';
      navigateTo(uri.replace(path: parentPath).toString());
      return;
    }
    final parent = Directory(state.currentPath).parent.path;
    if (parent != state.currentPath) navigateTo(parent);
  }

  void setSortField(SortField field) {
    final ascending = state.sortField == field ? !state.sortAscending : true;
    state = state.copyWith(
      entries: _sorted(state.entries, field, ascending),
      sortField: field,
      sortAscending: ascending,
    );
  }

  void toggleShowHidden() {
    state = state.copyWith(showHidden: !state.showHidden);
  }

  /// 퀵서치: 타이핑한 글자를 누적해 이름에 포함된 항목만 즉시 보여준다.
  void appendQuickFilterChar(String char) {
    final next = state.quickFilter + char;
    state = state.copyWith(quickFilter: next, selection: const {}, cursorIndex: null);
  }

  void backspaceQuickFilter() {
    if (state.quickFilter.isEmpty) return;
    final next = state.quickFilter.substring(0, state.quickFilter.length - 1);
    state = state.copyWith(quickFilter: next, selection: const {}, cursorIndex: null);
  }

  void clearQuickFilter() {
    if (state.quickFilter.isEmpty) return;
    state = state.copyWith(quickFilter: '');
  }

  /// `*`/`?` 와일드카드 패턴에 매치하는 항목을 선택에 추가하거나(add=true)
  /// 선택에서 제거한다(add=false).
  void selectByPattern(String pattern, {required bool add}) {
    final regex = _globToRegExp(pattern);
    final matching =
        state.visibleEntries.where((e) => regex.hasMatch(e.name)).map((e) => e.location).toSet();
    final next = add ? state.selection.union(matching) : state.selection.difference(matching);
    state = state.copyWith(selection: next);
  }

  /// 위/아래 화살표. 커서만 옮기고 [selection](진짜 다중선택)은 건드리지
  /// 않는다 — 스페이스를 눌러야 그 항목이 다중선택에 들어간다.
  void moveCursor(int delta) {
    final count = state.visibleEntries.length;
    if (count == 0) return;
    // 커서가 아직 없으면 방향에 상관없이 첫 항목(index 0)에서 시작한다 —
    // Up을 먼저 눌렀을 때 마지막 항목으로 점프하면 오히려 예측하기 어렵다.
    final current = state.cursorIndex ?? -1;
    final next = (current + delta).clamp(0, count - 1);
    state = state.copyWith(cursorIndex: next);
  }

  /// 스페이스바. 커서가 가리키는 항목을 다중선택 집합에 넣거나 뺀다(토글).
  /// 커서 자체는 움직이지 않는다.
  void toggleCursorSelection() {
    final index = state.cursorIndex;
    if (index == null) return;
    toggleSelection(index);
  }

  void selectOnly(int index) {
    final entries = state.visibleEntries;
    state = state.copyWith(selection: {entries[index].location}, cursorIndex: index);
  }

  void toggleSelection(int index) {
    final location = state.visibleEntries[index].location;
    final next = Set<Uri>.from(state.selection);
    if (!next.remove(location)) next.add(location);
    state = state.copyWith(selection: next, cursorIndex: index);
  }

  void selectRange(int index) {
    final entries = state.visibleEntries;
    final anchor = state.cursorIndex ?? index;
    final from = anchor < index ? anchor : index;
    final to = anchor < index ? index : anchor;
    final next = <Uri>{for (var i = from; i <= to; i++) entries[i].location};
    state = state.copyWith(selection: next);
  }

  void selectAll() {
    state = state.copyWith(
      selection: state.visibleEntries.map((e) => e.location).toSet(),
    );
  }

  void invertSelection() {
    final all = state.visibleEntries.map((e) => e.location).toSet();
    state = state.copyWith(selection: all.difference(state.selection));
  }

  void clearSelection() {
    state = state.copyWith(selection: const {});
  }
}

String homeDirectory() {
  if (Platform.isWindows) {
    return Platform.environment['USERPROFILE'] ?? 'C:\\';
  }
  return Platform.environment['HOME'] ?? '/';
}

final paneControllerProvider =
    StateNotifierProvider.family<PaneController, PaneState, PaneSide>(
  (ref, side) => PaneController(homeDirectory(), ref.read(ftpSessionManagerProvider.notifier)),
);

final activePaneProvider = StateProvider<PaneSide>((ref) => PaneSide.left);
