import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _iconBase = 'assets/icons/ui';

/// 툴바 등에서 쓰는 icons8 컬러 아이콘. on/off 두 상태를 구분해야 하는 토글
/// 버튼은 아이콘을 하나만 받았으므로, [active]가 false일 때 흐리게 표시해
/// 상태를 나타낸다. [flipVertical]은 정렬 화살표처럼 하나의 아이콘을
/// 오름/내림차순 방향으로 뒤집어 재사용할 때 쓴다.
class ToolIcon extends StatelessWidget {
  const ToolIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.active = true,
    this.flipVertical = false,
  });

  final String asset;
  final double size;
  final bool active;
  final bool flipVertical;

  @override
  Widget build(BuildContext context) {
    Widget icon = SvgPicture.asset('$_iconBase/$asset', width: size, height: size);
    if (flipVertical) {
      icon = Transform.flip(flipY: true, child: icon);
    }
    if (!active) {
      icon = Opacity(opacity: 0.4, child: icon);
    }
    return icon;
  }
}
