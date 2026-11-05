import 'package:flutter/material.dart';

/// 앱 전반의 메뉴 항목 높이. Material 기본(48)은 마우스 중심 데스크톱 앱에서
/// 행간이 너무 커서 낮춘다.
const double appMenuItemHeight = 36;

/// [PopupMenuItem]과 같지만 기본 높이가 [appMenuItemHeight]이다.
class AppMenuItem<T> extends PopupMenuItem<T> {
  const AppMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.padding,
    super.textStyle,
    required super.child,
  }) : super(height: appMenuItemHeight);
}
