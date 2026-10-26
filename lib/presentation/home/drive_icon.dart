import 'package:flutter/material.dart';

import '../../domain/entities/drive_entry.dart';

/// 네트워크·이동식 드라이브만 전용 아이콘을 쓰고, 나머지(내장 고정 디스크 등
/// 흔한 경우)는 null을 돌려줘 호출부가 평소 폴더/드라이브 아이콘을 그대로
/// 쓰게 한다 — 구분이 필요한 경우에만 다르게 보이면 충분하다.
// TODO(icons8): 이동식 드라이브는 icons8 전용 아이콘이 아직 없어 Material
// Icons.usb로 대신한다. 맞는 아이콘을 받으면 ToolIcon으로 교체할 것.
Widget? driveKindIcon(DriveKind kind, {required Color color, double size = 16}) {
  switch (kind) {
    case DriveKind.network:
      return Icon(Icons.cloud_outlined, size: size, color: color);
    case DriveKind.removable:
      return Icon(Icons.usb, size: size, color: color);
    case DriveKind.fixed:
    case DriveKind.unknown:
      return null;
  }
}
