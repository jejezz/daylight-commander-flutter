import 'dart:io';

import 'package:flutter/services.dart';

/// 선택한 로컬 항목들에 대해 OS 기본 컨텍스트 메뉴(Windows 탐색기의 셸 메뉴)를
/// 현재 마우스 커서 위치에 띄운다. 메뉴를 닫을 때까지 기다린다.
///
/// 현재는 Windows 만 지원한다 — macOS/Linux 는 외부 앱이 Finder/파일 관리자의
/// 컨텍스트 메뉴를 띄울 공개 API 가 없다. 지원하지 않거나 띄우지 못하면
/// `false` 를 돌려주니 호출한 쪽은 앱 자체 메뉴로 대체하면 된다.
class ShowOsContextMenu {
  const ShowOsContextMenu();

  static const _channel = MethodChannel('art.zoomon.daylightcommander/shell_menu');

  bool get isSupported => Platform.isWindows;

  Future<bool> call(List<String> paths) async {
    if (!isSupported || paths.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('show', paths) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
